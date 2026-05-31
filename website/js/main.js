/**
 * ThinkNote - Premium Notes App
 * Static Website Interaction Script
 */

document.addEventListener('DOMContentLoaded', () => {
  initMobileMenu();
  initScrollNavbar();
  initScrollReveal();
  initFooterYear();
  initEmailClipboard();
  highlightActiveLink();
});

/**
 * Responsive Mobile Menu Controller
 */
function initMobileMenu() {
  const toggleBtn = document.querySelector('.menu-toggle');
  const navMenu = document.querySelector('.nav-menu');
  const header = document.querySelector('.header');

  if (!toggleBtn || !navMenu) return;

  toggleBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    const isExpanded = toggleBtn.getAttribute('aria-expanded') === 'true';
    toggleBtn.setAttribute('aria-expanded', !isExpanded);
    navMenu.classList.toggle('active');

    // Update menu toggle markup
    if (isExpanded) {
      toggleBtn.innerHTML = '&#9776;'; // Hamburger character
      toggleBtn.setAttribute('aria-label', 'Open main menu');
    } else {
      toggleBtn.innerHTML = '&times;'; // Cross character
      toggleBtn.setAttribute('aria-label', 'Close main menu');
    }
  });

  // Close menu when clicking outside or resizing or clicking layout link
  document.addEventListener('click', (e) => {
    if (!navMenu.contains(e.target) && !toggleBtn.contains(e.target)) {
      if (navMenu.classList.contains('active')) {
        toggleBtn.click();
      }
    }
  });

  window.addEventListener('resize', () => {
    if (window.innerWidth > 768 && navMenu.classList.contains('active')) {
      toggleBtn.click();
    }
  });
}

/**
 * Handle sticky header blur density or styling updates on scrolling
 */
function initScrollNavbar() {
  const header = document.querySelector('.header');
  if (!header) return;

  window.addEventListener('scroll', () => {
    if (window.scrollY > 20) {
      header.style.boxShadow = '0 4px 6px -1px var(--primary-glow), 0 2px 4px -2px var(--primary-glow)';
    } else {
      header.style.boxShadow = 'none';
    }
  });
}

/**
 * Premium Animation Reveals on Page Scroll
 */
function initScrollReveal() {
  // Check if user prefers reduced motion
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReducedMotion) return;

  const revealElements = document.querySelectorAll('.reveal');
  if (revealElements.length === 0) return;

  const revealObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('active');
        // Unobserve once revealed to keep scrolling fast and performance light
        observer.unobserve(entry.target);
      }
    });
  }, {
    root: null,
    threshold: 0.1,
    rootMargin: '0px 0px -40px 0px' // reveal slightly before reaching screen view
  });

  revealElements.forEach(el => revealObserver.observe(el));
}

/**
 * Update dynamic current year element in the footer
 */
function initFooterYear() {
  const yearElement = document.querySelector('#current-year');
  if (yearElement) {
    yearElement.textContent = new Date().getFullYear();
  }
}

/**
 * Clipboard tool for friendly primary email support copying
 */
function initEmailClipboard() {
  const copyBtn = document.querySelector('.btn-clipboard');
  const emailText = document.querySelector('.contact-email');

  if (!copyBtn || !emailText) return;

  copyBtn.addEventListener('click', () => {
    const rawEmail = emailText.textContent.trim();
    navigator.clipboard.writeText(rawEmail).then(() => {
      const originalText = copyBtn.textContent;
      copyBtn.textContent = 'Copied!';
      copyBtn.style.color = 'var(--success)';
      
      setTimeout(() => {
        copyBtn.textContent = originalText;
        copyBtn.style.color = 'var(--primary)';
      }, 2000);
    }).catch(() => {
      // Fallback if clipboard authorization fails
      console.warn('Unable to automatically copy email support path.');
    });
  });
}

/**
 * Style navbar menu links depending on active screen context
 */
function highlightActiveLink() {
  const currentPath = window.location.pathname;
  const navLinks = document.querySelectorAll('.nav-link');

  navLinks.forEach(link => {
    const href = link.getAttribute('href');
    if (!href) return;
    
    // Exact or partial index matching
    if (currentPath.endsWith(href) || (href === 'index.html' && currentPath.endsWith('/'))) {
      link.classList.add('active');
    } else {
      link.classList.remove('active');
    }
  });
}
