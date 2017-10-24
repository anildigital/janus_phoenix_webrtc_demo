import {Socket} from "phoenix"

var Events = (function (channel) {

    var init = function() {
        channel.on("events", gotMessageFromServer)
    }

    function gotMessageFromServer(message) {
        console.log("Events::: Got message from server", message)
        console.log("message janus",message["janus"])
        console.log("message leaving", message["leaving"])
        console.log((message["janus"] === "event") && (message["leaving"] !== undefined))

        if( (message["janus"] === "event") && (message["unpublished"] !== undefined)) {
            var element = $("div[publisher_id='" + message["unpublished"] +"']")
            element.remove();
        }
        else if( (message["janus"] === "event") && (message["leaving"] !== undefined)) {
            console.log("Came here")
            var element = $("div[publisher_id='" + message["leaving"] +"']")
            console.log("found element", element)
            element.remove();
            console.log("Removed element");
        } else {
            console.log("Not handled");
            console.log(message)
        }
    }

    function send(event) {
        channel.push("events", event);
    }

    return {
        init: init,
        send: send
    }
})

export default Events
