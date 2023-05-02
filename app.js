// run with: npx serve .

window.post_message = (message) => {
    const content_el = document.getElementById("content");
    const new_el = document.createElement("div");
    new_el.textContent = message;
    content_el.appendChild(new_el);
    return true;
}
