import qrcode

urls = {
    "phontee.png": "https://www.linkedin.com/in/phontee/",
    "alberto-r.png": "https://www.linkedin.com/in/alberto-rguez-fdez/",
    "repo.png" : "https://github.com/mifonpe/sandboxed-agentic-platform-eks"
}

for name, link in urls.items():
    img = qrcode.make(link)
    img.save(name)
