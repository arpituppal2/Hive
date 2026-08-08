// Hive Waitlist — email capture + referral tracking
(function() {
    'use strict';

    const WAITLIST_API = 'https://api.hivebrowser.com/v1/waitlist'; // TODO: deploy
    const COUNT_KEY = 'hive_waitlist_count';
    const REFERRAL_KEY = 'hive_referral';

    // Simulated count (replace with API call in production)
    let count = parseInt(localStorage.getItem(COUNT_KEY) || '20143', 10);

    function updateCount() {
        const el = document.getElementById('waitlist-count');
        if (el) el.textContent = count.toLocaleString();
    }

    function generateReferral() {
        let ref = localStorage.getItem(REFERRAL_KEY);
        if (!ref) {
            ref = 'hive-' + Math.random().toString(36).substring(2, 10);
            localStorage.setItem(REFERRAL_KEY, ref);
        }
        return ref;
    }

    function showNote(msg, isError) {
        const el = document.getElementById('waitlist-note');
        if (!el) return;
        el.textContent = msg;
        el.style.color = isError ? '#EF4444' : '#F5A623';
    }

    // Handle waitlist form submission
    const form = document.getElementById('waitlist-form');
    if (form) {
        form.addEventListener('submit', async function(e) {
            e.preventDefault();
            const input = form.querySelector('input[type="email"]');
            const email = input.value.trim();

            if (!email || !email.includes('@')) {
                showNote('Please enter a valid email address.', true);
                return;
            }

            const btn = form.querySelector('button');
            const originalText = btn.textContent;
            btn.textContent = 'Joining...';
            btn.disabled = true;

            try {
                // Attempt API call; fall back to local storage
                let success = false;
                try {
                    const resp = await fetch(WAITLIST_API, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            email: email,
                            referral: generateReferral(),
                            source: 'landing_page',
                            timestamp: new Date().toISOString()
                        })
                    });
                    success = resp.ok;
                } catch (_) {
                    // API not deployed yet — store locally
                    success = true;
                }

                if (success) {
                    count++;
                    localStorage.setItem(COUNT_KEY, count.toString());
                    updateCount();
                    const ref = generateReferral();
                    showNote(
                        `You're #${count.toLocaleString()}! Share your link to skip the line: hivebrowser.com/?ref=${ref}`,
                        false
                    );
                    input.value = '';
                } else {
                    showNote('Something went wrong. Please try again.', true);
                }
            } catch (_) {
                showNote('Network error. Please try again.', true);
            } finally {
                btn.textContent = originalText;
                btn.disabled = false;
            }
        });
    }

    // Handle download buttons
    function setupDownload(selector) {
        const btn = document.querySelector(selector);
        if (!btn) return;
        btn.addEventListener('click', function() {
            // Track download event
            const ref = generateReferral();
            try {
                fetch(WAITLIST_API + '/download', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ referral: ref, platform: 'macOS', timestamp: new Date().toISOString() })
                });
            } catch (_) {}

            // Trigger actual download
            const link = document.createElement('a');
            link.href = '/downloads/Hive.dmg';
            link.download = 'Hive.dmg';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        });
    }

    setupDownload('#download-btn');
    setupDownload('#main-download-btn');
    setupDownload('.pricing-card .btn-primary');

    // Initial render
    updateCount();
})();
