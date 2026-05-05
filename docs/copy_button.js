document.querySelectorAll("pre:has(code)").forEach((block) => {
  const btn = document.createElement("button");
  btn.className = "copy-btn no-select";
  btn.textContent = "Copy";

  btn.addEventListener("click", () => {
    const code = block.innerText
      .replace(/^\$\s*/m, "")
      .replace(new RegExp(`${btn.textContent}$`), '');
    navigator.clipboard.writeText(code.trim() + '\n').then(() => {
      btn.textContent = "Copied!";
      setTimeout(() => (btn.textContent = "Copy"), 1500);
    });
  });

  block.appendChild(btn);
});
