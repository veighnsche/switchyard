// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded "><a href="introduction.html">Introduction</a></li><li class="chapter-item expanded "><a href="quickstart.html">Quickstart</a></li><li class="chapter-item expanded "><a href="safety-first.html">Safety First</a></li><li class="chapter-item expanded "><a href="architecture.html">Architecture Overview</a></li><li class="chapter-item expanded "><a href="concepts/index.html">Concepts</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="concepts/plan-actions-ids.html">Plan, Actions, and IDs</a></li><li class="chapter-item expanded "><a href="concepts/preflight.html">Preflight</a></li><li class="chapter-item expanded "><a href="concepts/apply.html">Apply</a></li><li class="chapter-item expanded "><a href="concepts/rollback.html">Rollback</a></li><li class="chapter-item expanded "><a href="concepts/locking.html">Locking</a></li><li class="chapter-item expanded "><a href="concepts/rescue.html">Rescue</a></li><li class="chapter-item expanded "><a href="concepts/exdev.html">Cross-filesystem (EXDEV)</a></li><li class="chapter-item expanded "><a href="concepts/audit-facts.html">Audit Facts and Redaction</a></li></ol></li><li class="chapter-item expanded "><a href="how-tos/index.html">How-Tos</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="how-tos/lock-manager.html">Configure a Lock Manager</a></li><li class="chapter-item expanded "><a href="how-tos/safepath.html">Use SafePath</a></li><li class="chapter-item expanded "><a href="how-tos/audit-capture.html">Capture and Verify Audit</a></li><li class="chapter-item expanded "><a href="how-tos/validate-facts.html">Validate Facts Against Schema v2</a></li><li class="chapter-item expanded "><a href="how-tos/prune-backups.html">Prune Backups</a></li></ol></li><li class="chapter-item expanded "><a href="reference/index.html">Reference</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="reference/public-api.html">Public API (rustdoc)</a></li><li class="chapter-item expanded "><a href="reference/error-codes.html">Error Codes</a></li><li class="chapter-item expanded "><a href="reference/preflight-schema.html">Preflight Schema</a></li><li class="chapter-item expanded "><a href="reference/audit-schema.html">Audit Event Schema (v2)</a></li><li class="chapter-item expanded "><a href="reference/policy-knobs.html">Policy Knobs</a></li><li class="chapter-item expanded "><a href="reference/operational-bounds.html">Operational Bounds</a></li></ol></li><li class="chapter-item expanded "><a href="recovery-playbook.html">Recovery Playbook</a></li><li class="chapter-item expanded "><a href="troubleshooting.html">Troubleshooting</a></li><li class="chapter-item expanded "><a href="common-pitfalls.html">Common Pitfalls</a></li><li class="chapter-item expanded "><a href="faq.html">FAQ</a></li><li class="chapter-item expanded "><a href="glossary.html">Glossary</a></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0].split("?")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
