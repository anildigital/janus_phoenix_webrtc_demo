var peerConnection;
var peerConnectionForAnswer;
var localStream;
var previousStream;

var start;
var stop;


var WebRTC = (function (channel) {

    var STUN = {
        'url': 'stun:stun.l.google.com:19302',
    };
    var TURN = {
        url: 'turn:user@139.59.26.81:3478',
        credential: 'root',
        username: 'root'
    };
    var peerConnectionConfig = {
        iceServers: [STUN, TURN],
        bundlePolicy: "balanced"
    };

    var pcConstraints = {
        "optional": [{ "DtlsSrtpKeyAgreement": true }]
    };

    var init = function () {
        channel.on("data", gotMessageFromServer)

        $("#shareVideo").click(shareVideo);
        $("#shareScreen").click(shareScreenTrigger);

        $("#stopSharing").hide();

        $("body").onbeforeunload = function () {
            return webrtc.stopPublishing()
        }
        $("#stopSharing").click(function () {
            return webrtc.stopPublishing();
        })
    }

    var unpublish = function() {
        if (localStream) {
            var tracks = localStream.getTracks();
            for(var i in tracks) {
                var mst = tracks[i];
                if(mst !== null && mst !== undefined)
                    mst.stop();
            }
        }
        channel.push("unpublish")
    }


    var reSharevideo = function () {
        var constraints = {
            video: true,
            audio: true,
        };

        if (navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices
                     .getUserMedia(constraints)
                     .then(getUserMediaSuccessReshare)
                     .catch(errorHandler);
        } else {
            alert('Your browser does not support getUserMedia API');
        }
    }


    var shareVideo = function () {
        var constraints = {
            video: true,
            audio: true,
        };

        if (navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices
                     .getUserMedia(constraints)
                     .then(getUserMediaSuccess)
                     .catch(errorHandler);
        } else {
            alert('Your browser does not support getUserMedia API');
        }
    }

    function getUserMediaSuccess(stream) {
        if (previousStream) {
            previousStream = localStream
            getUserMediaSuccessReshare(stream);
            return;
        }

        localStream = stream;
        previousStream = stream;

        localStream.getVideoTracks()[0].onended = function () {
            webrtc.stopPublishing();
        };

        $('#videolocal').append('<video class="localstream" muted="muted" class="rounded centered" id="myvideo" height="100%" width="100%" autoplay/>');

        stream.getVideoTracks();
        $('#myvideo').get(0).srcObject = stream;
        webrtc.startPublishing();
    }

    function getUserMediaSuccessReshare(stream) {
        localStream = stream;

        // localStream.getVideoTracks()[0].onended = function () {
        //     webrtc.stopPublishing();
        // };

        // stream.getVideoTracks();
        // $('#myvideo').get(0).srcObject = stream;

        // previousStream.removeTrack(previousStream.getVideoTracks()[0]);

        // peerConnection.addTrack(stream.getVideoTracks()[0], stream);

        peerConnection
            .removeStream(previousStream);

        peerConnection
            .addStream(stream);

        $('#myvideo').get(0).srcObject = stream;

        republish();
    }


    var stopPublishing = function () {
        var userId = $("#app_data").attr("user_id");
        var userId = $("#app_data").attr("name");

        localStream.getTracks().forEach(track => track.stop())

        channel.push("stop", { user_id: userId, name: name });

        $(".remoteVideo").remove();
        $("#shareVideo").show();
        $("#stopSharing").hide();
        $(".localstream").remove();

        $("body").removeClass("livestrip")
        $(".localstream").removeClass("borderBlink")
    }


    var republish = function () {
        $("body").addClass("livestrip")
        $(".localstream").addClass("borderBlink")
//        $("#shareVideo").hide();
        $("#stopSharing").show();

        // peerConnection = new RTCPeerConnection(peerConnectionConfig, pcConstraints);
        // peerConnection.onicecandidate = gotIceCandidate;

        peerConnection.onicecandidate = function() {
            consolel.log("noActionTaken on republish for onicecandidate")
        }

        peerConnection.addEventListener('iceconnectionstatechange', function (e) {
            console.log('ice state change', peerConnection.iceConnectionState);
        });

        // previousStream.removeTrack(previousStream.getVideoTracks()[0]);

        // peerConnection.addTrack(localStream.getVideoTracks()[0], localStream);

        // peerConnection
        //     .addStream(localStream);

        $("#startPublishing").addClass("hide");
        $("#stopPublishing").removeClass("hide");
        $("#publisherButtons").removeClass("hide");

        var publisherConstraints = {
            'mandatory': {
                'OfferToReceiveAudio': false,
                'OfferToReceiveVideo': false
            }
        }

        start = new Date();
        peerConnection
            .createOffer(createdDescriptionRepublish, errorHandler, publisherConstraints);

        $("#publisherButtons").removeClass("hide");

        $("#muteAudio").click(function () {
            video.toggleAudio(localStream);
        });

        $("#muteVideo").click(function () {
            video.toggleVideo(localStream);
        });
    }

    var startPublishing = function () {
        $("body").addClass("livestrip")
        $(".localstream").addClass("borderBlink")
        // $("#shareVideo").hide();
        $("#stopSharing").show();

        peerConnection = new RTCPeerConnection(peerConnectionConfig, pcConstraints);
        peerConnection.onicecandidate = gotIceCandidate;

        peerConnection.addEventListener('iceconnectionstatechange', function (e) {
            console.log('ice state change', peerConnection.iceConnectionState);
        });

        peerConnection
            .addStream(localStream);

        $("#startPublishing").addClass("hide");
        $("#stopPublishing").removeClass("hide");
        $("#publisherButtons").removeClass("hide");

        var publisherConstraints = {
            'mandatory': {
                'OfferToReceiveAudio': false,
                'OfferToReceiveVideo': false
            }
        }

        start = new Date();
        peerConnection
            .createOffer(createdDescription, errorHandler, publisherConstraints);

        $("#publisherButtons").removeClass("hide");

        $("#muteAudio").click(function () {
            video.toggleAudio(localStream);
        });

        $("#muteVideo").click(function () {
            video.toggleVideo(localStream);
        });
    }

    function gotMessageFromServer(message) {
        console.log("Got message from server", message)

        var jsep = message.jsep;
        var sdp = jsep;

        console.log("SDP received is", sdp.type)

        if (sdp.type === 'offer') {
            console.log("remote handle is ", message.remote_handle_id)
            console.log("publisher id is ", message.publisher_id)
            console.log("display is ", message.display)
            createAnswer(sdp, message.remote_handle_id, message.publisher_id, message.display);
        } else {
            console.log("Got", sdp.type);
            stop = new Date();
            console.log("Time it took to receive was", stop - start, "milliseconds");
            peerConnection.setRemoteDescription(new RTCSessionDescription(sdp, function () { }, errorHandler));
        }
    }

    function createAnswer(offerSdp, remote_handle_id, publisher_id, display) {

        if (remote_handle_id === undefined) {
            console.log("Not doing anything in createAnswer and returning immediately")
            return;
        }

        var receiverConstraints = {
            'mandatory': {
                'OfferToReceiveAudio': true,
                'OfferToReceiveVideo': true
            }
        }
        var peerConnectionForAnswer = new RTCPeerConnection(peerConnectionConfig, pcConstraints);
        peerConnectionForAnswer.onicecandidate = function (event) { gotIceCandidateAnswer(event, remote_handle_id) }
        peerConnectionForAnswer.onaddstream = function (event) { gotRemoteStream(event, remote_handle_id, publisher_id, display) }
        peerConnectionForAnswer.setRemoteDescription(new RTCSessionDescription(offerSdp), function () {
            peerConnectionForAnswer.createAnswer(function (description) {
                createdDescriptionAnswer(description, peerConnectionForAnswer, remote_handle_id)
            }, errorHandler, receiverConstraints)
        }, errorHandler);
    }

    function gotIceCandidate(event) {
        console.log("gotIceCandidateOffer")
        console.log(event);
        if (event.candidate != null) {
            channel.push("ice", {
                ice: {
                    body: {
                        candidate: event.candidate.candidate,
                        sdpMLineIndex: event.candidate.sdpMLineIndex,
                        sdp: event.candidate.sdp,
                        sdpMid: event.candidate.sdpMid
                    }
                },
                remote_handle_id: null
            })
        } else {
            console.log("Ice completed - offer")
            console.log("Pushing completed candidate - offer");
            channel.push("ice", { ice: { body: { "completed": true } }, remote_handle_id: null })
        }
    }

    function gotIceCandidateAnswer(event, handle) {
        console.log("gotIceCandidateAnswer")
        console.log(event);
        if (event.candidate != null) {
            console.log("Pushing ice candidate", handle)
            channel.push("ice", {
                ice: {
                    body: {
                        candidate: event.candidate.candidate,
                        sdpMLineIndex: event.candidate.sdpMLineIndex,
                        sdp: event.candidate.sdp,
                        sdpMid: event.candidate.sdpMid
                    }
                },
                remote_handle_id: handle
            })
        } else {
            console.log("Ice completed - answer");
            console.log("Pushing completed candidate - answer", handle);
            channel.push("ice", { ice: { body: { "completed": true } }, remote_handle_id: handle })
        }
    }

    function createdDescription(description) {
        var teamName = $("#app_data").attr("team_name");
        var roomId = $("#app_data").attr("room_id");
        var teamId = $("#app_data").attr("team_id");
        if (!roomId) {
            roomId = "";
        }
        peerConnection.setLocalDescription(description, function () {
            var data = {
                jsep: {
                    body: {
                        type: description.type,
                        sdp: description.sdp
                    }
                }
            }

            console.log("Sending offer");
            channel.push("offer", data)
        }, errorHandler);
    }


    function createdDescriptionRepublish(description) {
        peerConnection.setLocalDescription(description, function () {
            var data = {
                jsep: {
                    body: {
                        type: description.type,
                        sdp: description.sdp
                    }
                }
            }

            console.log("Sending republish offer");
            channel.push("offer_publish", data)
        }, errorHandler);
    }

    function createdDescriptionAnswer(description, peerConnectionForAnswer, handle) {
        console.log("Setting local description");
        peerConnectionForAnswer.setLocalDescription(description, function () {
            var data = {
                jsep: {
                    body: {
                        type: description.type,
                        sdp: description.sdp
                    }
                },
                remote_handle_id: handle
            }
            console.log("Sending answer", data);
            channel.push("answer", data)
        }, errorHandler);
    }

    function gotRemoteStream(event, remote_handle_id, publisher_id, display) {
        var remoteVideoTitle = "Remote Video " + publisher_id;
        var videoTag = ""

        display = display.split("_")[0];
        var source = $("#remoteVideoTemplate").html();
        var template = Handlebars.compile(source);
        var context = {
            remoteVideoTitle: remoteVideoTitle,
            videoTag: videoTag,
            remote_handle_id: remote_handle_id,
            publisher_id: publisher_id,
            display: display
        };
        var html = template(context);

        $("#allVideos").append(html).ready(function () {
            var remoteVideoId = '#remotevideo' + publisher_id;
            $('#remotevideo' + publisher_id).get(0).srcObject = event.stream;
        });
    }

    function startShareWebrtcScreen() {
        shareScreenTrigger();
    }

    var shareScreenTrigger = function () {
        var f = function (event) {
            if ((event.data.sourceId != undefined) && (event.data.sourceId != null) && (event.data.sourceId != "")) {
                // stopPublishing(shareScreen.bind(null, event.data.sourceId));
                shareScreen(event.data.sourceId);
            } else {
                return false;
            }
            // TODO fix this remove event listener properly.
            window.removeEventListener("message", f, false);
        };
        window.addEventListener('message', f);
        window.postMessage({ type: 'janusGetScreen' }, '*');
    }

    var shareScreen = function (sourceId) {
        var constraints = {
            video: {
                mandatory: {
                    chromeMediaSource: "desktop",
                    maxWidth: 1280,
                    maxHeight: 800,
                    minFrameRate: 3,
                    maxFrameRate: 3,
                    chromeMediaSourceId: sourceId
                },
                optional: [
                    {
                        googLeakyBucket: true
                    },
                    {
                        googTemporalLayeredScreencast: true
                    }
                ]
            }
        }
        if (navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices
                .getUserMedia(constraints)
                .then(getUserMediaAudio)
                .catch(errorHandler);
        } else {
            alert('Your browser does not support getUserMedia API');
        }
    }

    function getUserMediaAudio(screenStream) {
        var constraints = {
            audio: true
        };

        if (navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices
                .getUserMedia(constraints)
                .then(function(audioStream){
                    var audioTrack = audioStream.getAudioTracks()[0];
                    screenStream.addTrack( audioTrack );
                    getUserMediaSuccessReshare(screenStream);
                })
                .catch(errorHandler);
        } else {
            alert('Your browser does not support getUserMedia API');
        }
    }

    function errorHandler(error) {
        console.log(error);
        console.log(error.lineNumber);
        throw (error);
    }

    return {
        init: init,
        startPublishing: startPublishing,
        stopPublishing: stopPublishing,
        unpublish: unpublish,
        reSharevideo: reSharevideo,
        stopPublishing: stopPublishing
    }
})

export default WebRTC
