// run with: npx serve .

window.post_message = (message) => {
    // Parse the JSON string into an object
    var data = JSON.parse(message);

    if (data.type === "heartbeat") {
        console.log("Received heartbeat");
        displayHeartbeat();
    } else if (data.type === "detectedObjects") {
        var detectedObjects = data.objects;

        // Clear any previous data displayed on the web page
        clearPreviousData();

        // Iterate through the detected objects and process them
        for (var i = 0; i < detectedObjects.length; i++) {
            var obj = detectedObjects[i];
            var x = obj.x;
            var y = obj.y;
            var width = obj.width;
            var height = obj.height;
            var name = obj.name;
            var confidence = obj.confidence;

            // Process the detected object (e.g., display it on the web page)
            displayObject(x, y, width, height, name, confidence);
        }
    }
};

function clearPreviousData() {
    const content_el = document.getElementById("content");
    content_el.innerHTML = '';
}

function displayObject(x, y, width, height, name, confidence) {
    const content_el = document.getElementById("content");
    const new_el = document.createElement("div");
    new_el.textContent = `${name} (${confidence.toFixed(2)}): [x: ${x}, y: ${y}, width: ${width}, height: ${height}]`;
    content_el.appendChild(new_el);
}

function displayHeartbeat() {
    const content_el = document.getElementById("content");
    const new_el = document.createElement("div");
    new_el.textContent = "Received heartbeat";
    content_el.appendChild(new_el);
}