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

internal import LiveKitWebRTC

protocol SignalClientDelegate: AnyObject, Sendable {
    func signalClient(_ signalClient: SignalClient, didUpdateConnectionState newState: ConnectionState, oldState: ConnectionState, disconnectError: TransportError?) async
    func signalClient(_ signalClient: SignalClient, didReceiveConnectResponse connectResponse: SignalClient.ConnectResponse) async
    func signalClient(_ signalClient: SignalClient, didReceiveAnswer answer: LKRTCSessionDescription, offerId: UInt32) async
    func signalClient(_ signalClient: SignalClient, didReceiveOffer offer: LKRTCSessionDescription, offerId: UInt32) async
    func signalClient(_ signalClient: SignalClient, didReceiveIceCandidate iceCandidate: IceCandidate, target: Applooma_SignalTarget) async
    func signalClient(_ signalClient: SignalClient, didUnpublishLocalTrack localTrack: Applooma_TrackUnpublishedResponse) async
    func signalClient(_ signalClient: SignalClient, didUpdateParticipants participants: [Applooma_ParticipantInfo]) async
    /// A message handed over as received, after its decoded counterpart above has been applied.
    func signalClient(_ signalClient: SignalClient, didReceiveEncodedResponse response: SignalClient.EncodedResponse) async
    func signalClient(_ signalClient: SignalClient, didUpdateRoom room: Applooma_Room) async
    func signalClient(_ signalClient: SignalClient, didUpdateSpeakers speakers: [Applooma_SpeakerInfo]) async
    func signalClient(_ signalClient: SignalClient, didUpdateConnectionQuality connectionQuality: [Applooma_ConnectionQualityInfo]) async
    func signalClient(_ signalClient: SignalClient, didUpdateRemoteMute trackSid: Track.Sid, muted: Bool) async
    func signalClient(_ signalClient: SignalClient, didUpdateTrackStreamStates streamStates: [Applooma_StreamStateInfo]) async
    func signalClient(_ signalClient: SignalClient, didUpdateSubscribedCodecs codecs: [Applooma_SubscribedCodec], qualities: [Applooma_SubscribedQuality], forTrackSid sid: String) async
    func signalClient(_ signalClient: SignalClient, didReceiveRoomMoved response: Applooma_RoomMovedResponse) async
    func signalClient(_ signalClient: SignalClient, didUpdateSubscriptionPermission permission: Applooma_SubscriptionPermissionUpdate) async
    func signalClient(_ signalClient: SignalClient, didUpdateToken token: String) async
    func signalClient(_ signalClient: SignalClient, didReceiveLeave action: Applooma_LeaveRequest_Action, reason: Applooma_DisconnectReason, regions: Applooma_RegionSettings?) async
    func signalClient(_ signalClient: SignalClient, didSubscribeTrack trackSid: Track.Sid) async
    func signalClient(_ signalClient: SignalClient, didReceiveMediaSectionsRequirement requirement: Applooma_MediaSectionsRequirement) async
    func signalClient(_ signalClient: SignalClient, didReceiveDataTrackResponse data: Data) async
}
