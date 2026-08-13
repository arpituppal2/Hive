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


// ── Scroll-triggered reveal animations ──
document.addEventListener('DOMContentLoaded', function() {
  var observer = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add('revealed');
      }
    });
  }, { threshold: 0.15 });

  document.querySelectorAll('.bento-card, .pricing-card, .compare-table tr, .section-title, .hero-visual')
    .forEach(function(el) { el.classList.add('reveal'); observer.observe(el); });

  // ── Waitlist counter animation ──
  var countEl = document.getElementById('waitlist-count');
  var target = 20000;
  var duration = 2000;
  var start = performance.now();
  function tick(now) {
    var elapsed = now - start;
    var progress = Math.min(elapsed / duration, 1);
    // Ease-out quad
    var eased = 1 - (1 - progress) * (1 - progress);
    var val = Math.round(5000 + (target - 5000) * eased);
    countEl.textContent = val.toLocaleString();
    if (progress < 1) requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);

  // ── Particle canvas ──
  var canvas = document.createElement('canvas');
  canvas.id = 'particles';
  canvas.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:0;';
  document.body.prepend(canvas);
  var ctx = canvas.getContext('2d');
  var particles = [];
  var PARTICLE_COUNT = 40;

  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }
  resize();
  window.addEventListener('resize', resize);

  for (var i = 0; i < PARTICLE_COUNT; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      r: Math.random() * 2 + 1,
      vx: (Math.random() - 0.5) * 0.3,
      vy: (Math.random() - 0.5) * 0.3,
      opacity: Math.random() * 0.3 + 0.1
    });
  }

  function drawParticles() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    particles.forEach(function(p) {
      p.x += p.vx;
      p.y += p.vy;
      if (p.x < 0) p.x = canvas.width;
      if (p.x > canvas.width) p.x = 0;
      if (p.y < 0) p.y = canvas.height;
      if (p.y > canvas.height) p.y = 0;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(249, 115, 22, ' + p.opacity + ')';
      ctx.fill();
      // Draw lines between nearby particles
      particles.forEach(function(q) {
        var dx = p.x - q.x, dy = p.y - q.y;
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 120) {
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(q.x, q.y);
          ctx.strokeStyle = 'rgba(249, 115, 22, ' + (0.04 * (1 - dist/120)) + ')';
          ctx.lineWidth = 0.5;
          ctx.stroke();
        }
      });
    });
    requestAnimationFrame(drawParticles);
  }
  requestAnimationFrame(drawParticles);
});
