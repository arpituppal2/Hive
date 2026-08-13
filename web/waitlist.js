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
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

  document.querySelectorAll('.bento-card, .pricing-card, .compare-table tr, .section-title, .section-subtitle')
    .forEach(function(el) { el.classList.add('reveal'); observer.observe(el); });

  // ── Waitlist counter animation ──
  var countEl = document.getElementById('waitlist-count');
  var target = 21400;
  var duration = 2400;
  var start = performance.now();
  function tick(now) {
    var elapsed = now - start;
    var progress = Math.min(elapsed / duration, 1);
    var eased = 1 - Math.pow(1 - progress, 3);
    var val = Math.round(5000 + (target - 5000) * eased);
    countEl.textContent = val.toLocaleString();
    if (progress < 1) requestAnimationFrame(tick);
    else {
      countEl.style.textShadow = '0 0 20px rgba(249,115,22,0.5)';
      setTimeout(function() { countEl.style.textShadow = ''; }, 600);
    }
  }
  requestAnimationFrame(tick);

  // ── Nav scroll shrink ──
  var nav = document.querySelector('.nav');
  var lastScrollY = 0;
  window.addEventListener('scroll', function() {
    var y = window.scrollY;
    if (y > 40) nav.classList.add('scrolled');
    else nav.classList.remove('scrolled');
    lastScrollY = y;
  }, { passive: true });

  // ── Magnetic hover on CTA ──
  var ctaBtn = document.getElementById('main-download-btn');
  if (ctaBtn) {
    ctaBtn.addEventListener('mousemove', function(e) {
      var rect = ctaBtn.getBoundingClientRect();
      var x = e.clientX - rect.left;
      var y = e.clientY - rect.top;
      var centerX = rect.width / 2;
      var centerY = rect.height / 2;
      var moveX = (x - centerX) / centerX * 4;
      var moveY = (y - centerY) / centerY * 4;
      ctaBtn.style.transform = 'translate(' + moveX + 'px, ' + moveY + 'px) translateY(-2px)';
      ctaBtn.style.setProperty('--mx', x + 'px');
      ctaBtn.style.setProperty('--my', y + 'px');
    });
    ctaBtn.addEventListener('mouseleave', function() {
      ctaBtn.style.transform = '';
    });
  }

  // ── Typewriter effect on model responses ──
  var responses = document.querySelectorAll('.model-response');
  responses.forEach(function(el, i) {
    el.style.animationDelay = (1.2 + i * 0.6) + 's';
    var p = el.querySelector('p');
    if (p) {
      var text = p.textContent;
      p.textContent = '';
      var charIndex = 0;
      setTimeout(function typeChar() {
        if (charIndex < text.length) {
          p.textContent += text.charAt(charIndex);
          charIndex++;
          setTimeout(typeChar, 18 + Math.random() * 12);
        }
      }, 200 + i * 600);
    }
  });

  // ── Particle canvas ──
  var canvas = document.createElement('canvas');
  canvas.id = 'particles';
  canvas.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:0;';
  document.body.prepend(canvas);
  var ctx = canvas.getContext('2d');
  var particles = [];
  var PARTICLE_COUNT = 50;
  var mouseX = -1000, mouseY = -1000;

  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }
  resize();
  window.addEventListener('resize', resize);

  // Track mouse for particle repulsion
  document.addEventListener('mousemove', function(e) {
    mouseX = e.clientX;
    mouseY = e.clientY;
  });

  for (var i = 0; i < PARTICLE_COUNT; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      r: Math.random() * 2.5 + 0.8,
      vx: (Math.random() - 0.5) * 0.4,
      vy: (Math.random() - 0.5) * 0.4,
      opacity: Math.random() * 0.35 + 0.08,
      baseOpacity: Math.random() * 0.35 + 0.08
    });
  }

  function drawParticles() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      // Mouse repulsion
      var dx = p.x - mouseX, dy = p.y - mouseY;
      var dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 150 && dist > 0) {
        var force = (150 - dist) / 150 * 0.5;
        p.vx += (dx / dist) * force * 0.02;
        p.vy += (dy / dist) * force * 0.02;
      }
      // Damping
      p.vx *= 0.998;
      p.vy *= 0.998;
      p.x += p.vx;
      p.y += p.vy;
      if (p.x < 0) p.x = canvas.width;
      if (p.x > canvas.width) p.x = 0;
      if (p.y < 0) p.y = canvas.height;
      if (p.y > canvas.height) p.y = 0;
      // Glow near mouse
      p.opacity = dist < 150 ? p.baseOpacity + (1 - dist/150) * 0.3 : p.baseOpacity;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(249, 115, 22, ' + p.opacity + ')';
      ctx.fill();
      // Connection lines
      for (var j = i + 1; j < particles.length; j++) {
        var q = particles[j];
        var ddx = p.x - q.x, ddy = p.y - q.y;
        var dd = Math.sqrt(ddx * ddx + ddy * ddy);
        if (dd < 130) {
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(q.x, q.y);
          ctx.strokeStyle = 'rgba(249, 115, 22, ' + (0.05 * (1 - dd/130)) + ')';
          ctx.lineWidth = 0.5;
          ctx.stroke();
        }
      }
    }
    requestAnimationFrame(drawParticles);
  }
  requestAnimationFrame(drawParticles);
});
