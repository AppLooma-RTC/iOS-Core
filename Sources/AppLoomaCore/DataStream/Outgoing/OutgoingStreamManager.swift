/*
 * Copyright 2026 the transport
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

// Extending the generic builder needs the runtime module by name; the facades
// themselves are re-exported through the transport.

/// Manages state of outgoing data streams.
actor OutgoingStreamManager: Loggable {
    typealias PacketHandler = @Sendable (Applooma_DataPacket) async throws -> Void
    typealias EncryptionProvider = @Sendable () -> EncryptionType

    private nonisolated let packetHandler: PacketHandler
    private nonisolated let encryptionProvider: EncryptionProvider

    init(packetHandler: @escaping PacketHandler, encryptionProvider: @escaping EncryptionProvider) {
        self.packetHandler = packetHandler
        self.encryptionProvider = encryptionProvider
    }

    // MARK: - Opening streams

    func sendText(_ text: String, options: StreamTextOptions) async throws -> TextStreamInfo {
        let info = TextStreamInfo(
            id: options.id ?? Self.uniqueID(),
            topic: options.topic,
            timestamp: Date(),
            totalLength: text.utf8.count, // Number of bytes in UTF-8 representation
            attributes: options.attributes,
            encryptionType: encryptionProvider(),
            operationType: .create,
            version: options.version,
            replyToStreamID: options.replyToStreamID,
            attachedStreamIDs: options.attachedStreamIDs,
            generated: false,
        )
        let writer = try await openTextStream(
            with: info,
            sendingTo: options.destinationIdentities,
        )
        try await writer.write(text)
        try await writer.close()

        return writer.info
    }

    func sendFile(_ fileURL: URL, options: StreamByteOptions) async throws -> ByteStreamInfo {
        guard let fileInfo = FileInfo(for: fileURL) else {
            throw StreamError.fileInfoUnavailable
        }
        let info = ByteStreamInfo(
            id: options.id ?? Self.uniqueID(),
            topic: options.topic,
            timestamp: Date(),
            totalLength: fileInfo.size, // Not overridable
            attributes: options.attributes,
            encryptionType: encryptionProvider(),
            mimeType: options.mimeType ?? fileInfo.mimeType ?? Self.byteMimeType,
            name: options.name ?? fileInfo.name,
        )
        let writer = try await openByteStream(
            with: info,
            sendingTo: options.destinationIdentities,
        )
        try await writer.write(contentsOf: fileURL)
        try await writer.close()

        return writer.info
    }

    func streamText(options: StreamTextOptions) async throws -> TextStreamWriter {
        let info = TextStreamInfo(
            id: options.id ?? Self.uniqueID(),
            topic: options.topic,
            timestamp: Date(),
            totalLength: nil,
            attributes: options.attributes,
            encryptionType: encryptionProvider(),
            operationType: .create,
            version: options.version,
            replyToStreamID: options.replyToStreamID,
            attachedStreamIDs: options.attachedStreamIDs,
            generated: false,
        )
        return try await openTextStream(
            with: info,
            sendingTo: options.destinationIdentities,
        )
    }

    func streamBytes(options: StreamByteOptions) async throws -> ByteStreamWriter {
        let info = ByteStreamInfo(
            id: options.id ?? Self.uniqueID(),
            topic: options.topic,
            timestamp: Date(),
            totalLength: options.totalSize,
            attributes: options.attributes,
            encryptionType: encryptionProvider(),
            mimeType: options.mimeType ?? Self.byteMimeType,
            name: options.name,
        )
        return try await openByteStream(
            with: info,
            sendingTo: options.destinationIdentities,
        )
    }

    private func openTextStream(
        with info: TextStreamInfo,
        sendingTo recipients: [Participant.Identity],
    ) async throws -> TextStreamWriter {
        try await openStream(with: info, sendingTo: recipients)
        return TextStreamWriter(
            info: info,
            destination: Destination(streamID: info.id, manager: self),
        )
    }

    private func openByteStream(
        with info: ByteStreamInfo,
        sendingTo recipients: [Participant.Identity],
    ) async throws -> ByteStreamWriter {
        try await openStream(with: info, sendingTo: recipients)
        return ByteStreamWriter(
            info: info,
            destination: Destination(streamID: info.id, manager: self),
        )
    }

    // MARK: - State

    /// Information about an open data stream.
    private struct Descriptor {
        let info: StreamInfo
        var writtenLength: Int = 0
        var chunkIndex: UInt64 = 0
    }

    /// Mapping between stream ID and descriptor for open streams.
    private var openStreams: [String: Descriptor] = [:]

    private func hasOpenStream(for streamID: String) -> Bool {
        openStreams[streamID] != nil
    }

    // MARK: - Packet sending

    private func openStream(
        with info: StreamInfo,
        sendingTo recipients: [Participant.Identity],
    ) async throws {
        guard openStreams[info.id] == nil else {
            throw StreamError.alreadyOpened
        }

        let header = Applooma_DataStream.Header(info)
        let packet = Applooma_DataPacket.with {
            $0.value = .streamHeader(header)
            $0.destinationIdentities = recipients.map(\.stringValue)
        }

        try await packetHandler(packet)

        let descriptor = Descriptor(info: info)
        openStreams[info.id] = descriptor
    }

    private func send(_ data: some StreamData, to id: String) async throws {
        for chunk in data.chunks(of: Self.chunkSize) {
            try await sendChunk(chunk, to: id)
        }
    }

    private func sendChunk(_ data: Data, to id: String) async throws {
        guard let descriptor = openStreams[id] else {
            throw StreamError.unknownStream
        }
        let chunk = Applooma_DataStream.Chunk.with {
            $0.streamID = id
            $0.chunkIndex = descriptor.chunkIndex
            $0.content = data
        }
        let packet = Applooma_DataPacket.with {
            $0.value = .streamChunk(chunk)
        }
        try await packetHandler(packet)

        openStreams[id]!.writtenLength += data.count
        openStreams[id]!.chunkIndex += 1
    }

    private func closeStream(with id: String, reason: String?) async throws {
        guard openStreams[id] != nil else {
            throw StreamError.unknownStream
        }

        let trailer = Applooma_DataStream.Trailer.with {
            $0.streamID = id
            $0.reason = reason ?? ""
        }
        let packet = Applooma_DataPacket.with {
            $0.value = .streamTrailer(trailer)
        }

        try await packetHandler(packet)
        openStreams[id] = nil
    }

    // MARK: - Destination

    fileprivate struct Destination: StreamWriterDestination {
        let streamID: String
        weak var manager: OutgoingStreamManager?

        var isOpen: Bool {
            get async {
                guard let manager else { return false }
                return await manager.hasOpenStream(for: streamID)
            }
        }

        func write(_ data: some StreamData) async throws {
            guard let manager else { throw StreamError.terminated }
            try await manager.send(data, to: streamID)
        }

        func close(reason: String?) async throws {
            guard let manager else { throw StreamError.terminated }
            try? await manager.closeStream(with: streamID, reason: reason)
        }
    }

    // MARK: - Constants & helpers

    /// Generates a unqiue ID for a new stream.
    private static func uniqueID() -> String {
        UUID().uuidString
    }

    /// Maximum number of bytes to send in a single chunk.
    private static let chunkSize = 15 * 1024

    /// Default MIME type to use for text streams.
    fileprivate static let textMimeType = "text/plain"

    /// Default MIME type to use for byte streams.
    private static let byteMimeType = "application/octet-stream"
}

// MARK: - To protocol types

extension Applooma_DataStream.Header {
    init(_ streamInfo: StreamInfo) {
        self = Applooma_DataStream.Header.with {
            $0.streamID = streamInfo.id
            $0.mimeType = (streamInfo as? ByteStreamInfo)?.mimeType ?? OutgoingStreamManager.textMimeType
            $0.topic = streamInfo.topic
            $0.timestampDate = streamInfo.timestamp
            if let totalLength = streamInfo.totalLength {
                $0.totalLength = UInt64(totalLength)
            }
            $0.attributes = streamInfo.attributes
            $0.encryptionType = streamInfo.encryptionType.toPBType()
            $0.contentHeader = Applooma_DataStream_Header_OneOf_ContentHeader(streamInfo)
        }
    }

    // Stream timestamps are in ms (13 digits)
    var timestampDate: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / TimeInterval(1000))
    }
}

extension Applooma_DataStream_Header.Builder {
    // Mirrors `Applooma_DataStream.Header.timestampDate`; setters live on the builder.
    var timestampDate: Date {
        get { Date(timeIntervalSince1970: TimeInterval(timestamp) / TimeInterval(1000)) }
        nonmutating set { timestamp = Int64(newValue.timeIntervalSince1970 * TimeInterval(1000)) }
    }
}

extension Applooma_DataStream_Header_OneOf_ContentHeader {
    init?(_ streamInfo: StreamInfo) {
        if let textStreamInfo = streamInfo as? TextStreamInfo {
            self = .textHeader(Applooma_DataStream.TextHeader.with {
                $0.operationType = Applooma_DataStream.OperationType(textStreamInfo.operationType)
                $0.version = Int32(textStreamInfo.version)
                $0.replyToStreamID = textStreamInfo.replyToStreamID ?? ""
                $0.attachedStreamIds = textStreamInfo.attachedStreamIDs
                $0.generated = textStreamInfo.generated
            })
            return
        } else if let byteStreamInfo = streamInfo as? ByteStreamInfo {
            self = .byteHeader(Applooma_DataStream.ByteHeader.with {
                if let name = byteStreamInfo.name { $0.name = name }
            })
            return
        }
        return nil
    }
}

extension Applooma_DataStream.OperationType {
    init(_ operationType: TextStreamInfo.OperationType) {
        self = Applooma_DataStream.OperationType(rawValue: operationType.rawValue) ?? .create
    }
}
