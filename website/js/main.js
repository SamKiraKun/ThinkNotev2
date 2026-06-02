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
  initContactForm();
});

// Clean SVGs for mobile menu states
const hamburgerSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="menu-toggle-icon"><line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="18" y2="18"/></svg>`;
const closeSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="menu-toggle-icon"><line x1="18" x2="6" y1="6" y2="18"/><line x1="6" x2="18" y1="6" y2="18"/></svg>`;

/**
 * Responsive Mobile Menu Controller
 */
function initMobileMenu() {
  const toggleBtn = document.querySelector('.menu-toggle');
  const navMenu = document.querySelector('.nav-menu');

  if (!toggleBtn || !navMenu) return;

  toggleBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    const isExpanded = toggleBtn.getAttribute('aria-expanded') === 'true';
    toggleBtn.setAttribute('aria-expanded', !isExpanded);
    navMenu.classList.toggle('active');

    // Update menu toggle markup with SVG
    if (isExpanded) {
      toggleBtn.innerHTML = hamburgerSvg;
      toggleBtn.setAttribute('aria-label', 'Open main menu');
    } else {
      toggleBtn.innerHTML = closeSvg;
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

  // Close menu on menu-link clicks (anchor targets)
  navMenu.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      if (navMenu.classList.contains('active')) {
        toggleBtn.click();
      }
    });
  });

  window.addEventListener('resize', () => {
    if (window.innerWidth > 768 && navMenu.classList.contains('active')) {
      toggleBtn.click();
    }
  });
}

/**
 * Handle sticky header shadow and styling updates on scrolling
 */
function initScrollNavbar() {
  const header = document.querySelector('.header');
  if (!header) return;

  // Initial state setup
  if (window.scrollY > 20) {
    header.style.boxShadow = 'var(--shadow-md)';
  } else {
    header.style.boxShadow = 'none';
  }

  window.addEventListener('scroll', () => {
    if (window.scrollY > 20) {
      header.style.boxShadow = 'var(--shadow-md)';
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
    threshold: 0.05,
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

// Clean SVGs for clipboard button states
const copyIconSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="copy-icon"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>`;
const checkIconSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="copy-icon"><path d="M20 6 9 17l-5-5"/></svg>`;

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
      // Premium visual feedback transformation
      copyBtn.innerHTML = `${checkIconSvg}<span class="btn-clipboard-text" style="color: var(--success)">Copied!</span>`;
      copyBtn.style.borderColor = 'var(--success)';
      copyBtn.style.backgroundColor = 'var(--color-primary-light)';
      
      setTimeout(() => {
        copyBtn.innerHTML = `${copyIconSvg}<span class="btn-clipboard-text">Copy</span>`;
        copyBtn.style.borderColor = '';
        copyBtn.style.backgroundColor = '';
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
    if (currentPath.endsWith(href) || (href === 'index.html' && (currentPath.endsWith('/') || currentPath === ''))) {
      link.classList.add('active');
    } else {
      link.classList.remove('active');
    }
  });
}

/**
 * Handle contact form validation and interactive submit transitions
 */
function initContactForm() {
  const form = document.querySelector('#thinknote-contact-form');
  const formCard = document.querySelector('#contact-form-section');
  if (!form || !formCard) return;

  const nameInput = document.querySelector('#contact-name');
  const emailInput = document.querySelector('#contact-email');
  const subjectInput = document.querySelector('#contact-subject');
  const messageInput = document.querySelector('#contact-message');
  const submitBtn = form.querySelector('.submit-btn');

  // Input helper to clear error states on typing
  const inputs = [nameInput, emailInput, subjectInput, messageInput];
  inputs.forEach(input => {
    input.addEventListener('input', () => {
      input.classList.remove('error');
      const errorMsg = document.querySelector(`#error-${input.id.replace('contact-', '')}`);
      if (errorMsg) {
        errorMsg.classList.add('sr-only');
      }
    });
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    let isValid = true;

    // 1. Name validation
    if (!nameInput.value.trim()) {
      showError(nameInput, 'error-name');
      isValid = false;
    }

    // 2. Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailInput.value.trim() || !emailRegex.test(emailInput.value.trim())) {
      showError(emailInput, 'error-email');
      isValid = false;
    }

    // 3. Subject validation
    if (!subjectInput.value.trim()) {
      showError(subjectInput, 'error-subject');
      isValid = false;
    }

    // 4. Message validation
    if (!messageInput.value.trim()) {
      showError(messageInput, 'error-message');
      isValid = false;
    }

    if (!isValid) return;

    // Show loading state
    const originalBtnHTML = submitBtn.innerHTML;
    submitBtn.disabled = true;
    submitBtn.innerHTML = `<span>Sending...</span><svg class="animate-spin" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="animation: spin 1s linear infinite;"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>`;

    // Add spin keyframe dynamically if not present
    if (!document.getElementById('spin-style')) {
      const style = document.createElement('style');
      style.id = 'spin-style';
      style.innerHTML = `@keyframes spin { to { transform: rotate(360deg); } }`;
      document.head.appendChild(style);
    }

    // Simulate API delay
    setTimeout(() => {
      // Transition to beautiful success state
      formCard.style.opacity = '0';
      formCard.style.transform = 'translateY(10px)';
      
      setTimeout(() => {
        formCard.innerHTML = `
          <div class="form-success-card">
            <div class="success-icon-wrapper">
              <svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
            </div>
            <h3>Message Sent!</h3>
            <p>Thank you for reaching out, Alex. We have received your message and our team will get back to you shortly.</p>
            <button class="btn btn-secondary" onclick="window.location.reload()">Send Another Message</button>
          </div>
        `;
        
        // Dynamically personalize success message name if available
        const nameVal = nameInput.value.trim().split(' ')[0];
        const successName = nameVal ? nameVal : 'there';
        formCard.querySelector('p').textContent = `Thank you for reaching out, ${successName}. We have received your message and our support team will get back to you shortly.`;
        
        formCard.style.opacity = '1';
        formCard.style.transform = 'translateY(0)';
      }, 300);
    }, 1200);
  });

  function showError(input, errorId) {
    input.classList.add('error');
    const errorMsg = document.getElementById(errorId);
    if (errorMsg) {
      errorMsg.classList.remove('sr-only');
    }
  }
}
