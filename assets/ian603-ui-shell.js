
(function(){
  'use strict';

  function el(tag, className, text){
    var node=document.createElement(tag);
    if(className) node.className=className;
    if(text!==undefined) node.textContent=text;
    return node;
  }

  function parseModuleMeta(){
    var title=document.title||'';
    var match=title.match(/IAN\s*603\s*[·|-]\s*Module\s*(\d+)\s*[·|-]\s*(.*)$/i);
    var number=match?match[1]:'';
    var name=match?match[2].trim():'Preparing Data for Analytics';
    if(!number){
      var brandMark=document.querySelector('.brand-mark');
      if(brandMark) number=(brandMark.textContent||'').trim();
    }
    if(!name){
      var heading=document.querySelector('.slide h1,.slide h2');
      if(heading) name=(heading.textContent||'').trim();
    }
    return {number:number||'',name:name||'Preparing Data for Analytics'};
  }

  function setupHeader(){
    var topbar=document.querySelector('.topbar');
    if(!topbar || topbar.dataset.ian603Shell==='ready') return;
    topbar.dataset.ian603Shell='ready';

    var meta=parseModuleMeta();
    var oldBrand=topbar.querySelector(':scope > .brand');
    var oldActions=topbar.querySelector(':scope > .top-actions');
    if(oldBrand) oldBrand.classList.add('shell-original-hidden');
    if(oldActions) oldActions.classList.add('shell-original-hidden');

    var mark=el('div','shell-brand-mark','DB');

    var titleWrap=el('div','shell-title-wrap');
    var modTitle=el('div','shell-module-title','Module '+meta.number);
    var courseTitle=el('div','shell-course-title','IAN 603 · '+meta.name);
    titleWrap.appendChild(modTitle);
    titleWrap.appendChild(courseTitle);

    var dbStatus=document.getElementById('dbStatus');
    if(dbStatus){
      dbStatus.classList.add('shell-db-status');
    }

    var status=el('div','shell-status');
    var statusText=el('span','shell-status-text','Slide 1');
    statusText.id='shellStatusText';
    var sep=el('span','shell-status-sep','·');
    var statusPct=el('span','shell-status-pct','0%');
    statusPct.id='shellStatusPct';
    status.appendChild(statusText);
    status.appendChild(sep);
    status.appendChild(statusPct);

    var actions=el('div','shell-actions');

    var progressBtn=document.getElementById('progressBtn') || document.getElementById('learningProgressBtn');
    if(progressBtn){
      progressBtn.classList.add('shell-progress-action');
      actions.appendChild(progressBtn);
    }

    var runBtn=document.getElementById('runSlideBtn');
    if(runBtn){
      runBtn.classList.add('shell-run-action');
      actions.appendChild(runBtn);
    }

    var settingsWrap=el('div','shell-settings-wrap');
    var settingsBtn=el('button','shell-settings-btn','⚙ Settings');
    settingsBtn.type='button';
    settingsBtn.setAttribute('aria-expanded','false');

    var settingsMenu=el('div','shell-settings-menu');
    settingsMenu.setAttribute('role','menu');

    var themeBtn=document.getElementById('themeBtn');
    var fullBtn=document.getElementById('fullBtn');
    if(themeBtn){
      themeBtn.setAttribute('role','menuitem');
      settingsMenu.appendChild(themeBtn);
    }
    if(fullBtn){
      fullBtn.setAttribute('role','menuitem');
      settingsMenu.appendChild(fullBtn);
    }

    var autoBtn=el('button','','Auto-hide Off');
    autoBtn.type='button';
    autoBtn.id='shellAutoHideBtn';
    autoBtn.setAttribute('role','menuitem');
    settingsMenu.appendChild(autoBtn);

    settingsWrap.appendChild(settingsBtn);
    settingsWrap.appendChild(settingsMenu);
    actions.appendChild(settingsWrap);

    var modulesBtn=document.getElementById('courseModulesBtn');
    if(modulesBtn){
      modulesBtn.classList.add('shell-modules-action');
      modulesBtn.textContent='☰ Modules';
      actions.appendChild(modulesBtn);
    }

    topbar.appendChild(mark);
    topbar.appendChild(titleWrap);
    if(dbStatus) topbar.appendChild(dbStatus);
    topbar.appendChild(status);
    topbar.appendChild(actions);

    settingsBtn.addEventListener('click',function(event){
      event.stopPropagation();
      var open=settingsMenu.classList.toggle('open');
      settingsBtn.setAttribute('aria-expanded',open?'true':'false');
    });
    settingsMenu.addEventListener('click',function(event){
      if(event.target!==autoBtn){
        settingsMenu.classList.remove('open');
        settingsBtn.setAttribute('aria-expanded','false');
      }
    });
    autoBtn.addEventListener('click',function(){
      var on=document.body.classList.toggle('shell-auto-hide');
      autoBtn.textContent=on?'Auto-hide On':'Auto-hide Off';
      settingsMenu.classList.remove('open');
      settingsBtn.setAttribute('aria-expanded','false');
    });
    document.addEventListener('click',function(event){
      if(!settingsWrap.contains(event.target)){
        settingsMenu.classList.remove('open');
        settingsBtn.setAttribute('aria-expanded','false');
      }
    });
    document.addEventListener('keydown',function(event){
      if(event.key==='Escape'){
        settingsMenu.classList.remove('open');
        settingsBtn.setAttribute('aria-expanded','false');
      }
    });

    if(oldActions){
      var leftovers=[].slice.call(oldActions.children);
      if(leftovers.length){
        var legacy=el('div','shell-legacy-status');
        leftovers.forEach(function(node){ legacy.appendChild(node); });
        topbar.appendChild(legacy);
      }
    }
  }

  function setupFooter(){
    var footer=document.querySelector('footer.bottombar, footer.bottom');
    if(!footer || footer.dataset.ian603Shell==='ready') return;
    footer.dataset.ian603Shell='ready';
    footer.classList.add('shell-bottom');

    var audioBlock=footer.querySelector('.audio-block');
    var bottomNav=footer.querySelector('.bottom-nav');
    var prevBtn=document.getElementById('prevBtn') || footer.querySelector('[onclick*="prevSlide"]');
    var nextBtn=document.getElementById('nextBtn') || footer.querySelector('[onclick*="nextSlide"]');

    if(audioBlock && bottomNav && prevBtn && nextBtn){
      var nav=el('div','presentation-nav');
      nav.setAttribute('aria-label','Slide navigation');

      var left=el('div','footer-left');
      var right=el('div','footer-right');

      prevBtn.textContent='‹';
      nextBtn.textContent='›';
      prevBtn.setAttribute('aria-label','Previous slide');
      nextBtn.setAttribute('aria-label','Next slide');

      left.appendChild(prevBtn);
      right.appendChild(nextBtn);
      nav.appendChild(left);
      nav.appendChild(bottomNav);
      nav.appendChild(right);

      footer.appendChild(nav);

      [].slice.call(footer.children).forEach(function(child){
        if(child===audioBlock || child===nav) return;
        if(child.children.length===0 && !(child.textContent||'').trim()) child.remove();
      });
    }

    var subtitle=document.getElementById('subtitleBar');
    if(subtitle) subtitle.classList.add('caption-strip');

    var audioPlayer=document.getElementById('audioPlayer');
    var audioPlay=document.getElementById('audioPlay');
    if(audioPlayer && audioPlay){
      audioPlayer.insertBefore(audioPlay,audioPlayer.firstChild);
    }

    var startNarration=document.getElementById('startNarration');
    var narrationToggle=document.getElementById('narrationToggle');
    if(startNarration && narrationToggle && audioPlay){
      startNarration.classList.add('shell-redundant-start');
    }
  }

  function setupSlideProgress(){
    var slides=[].slice.call(document.querySelectorAll('#slidesHost .slide'));
    if(!slides.length) slides=[].slice.call(document.querySelectorAll('.slide'));
    var statusText=document.getElementById('shellStatusText');
    var statusPct=document.getElementById('shellStatusPct');

    function activeIndex(){
      var idx=slides.findIndex(function(slide){return slide.classList.contains('active');});
      if(idx>=0) return idx;
      var select=document.getElementById('slideSelect');
      if(select && select.selectedIndex>=0) return Math.min(select.selectedIndex,slides.length-1);
      return 0;
    }

    function sync(){
      var idx=activeIndex();
      var total=slides.length||1;
      var num=idx+1;
      var pct=Math.max(1,Math.round((num/total)*100));
      if(statusText) statusText.textContent='Slide '+num+'/'+total;
      if(statusPct) statusPct.textContent=pct+'%';
    }

    slides.forEach(function(slide){
      try{
        new MutationObserver(sync).observe(slide,{attributes:true,attributeFilter:['class']});
      }catch(e){}
    });

    var select=document.getElementById('slideSelect');
    if(select) select.addEventListener('change',function(){setTimeout(sync,0);});
    var prev=document.getElementById('prevBtn');
    var next=document.getElementById('nextBtn');
    if(prev) prev.addEventListener('click',function(){setTimeout(sync,0);});
    if(next) next.addEventListener('click',function(){setTimeout(sync,0);});
    document.addEventListener('keydown',function(event){
      if(['ArrowLeft','ArrowRight','PageUp','PageDown','Home','End'].indexOf(event.key)>=0){
        setTimeout(sync,0);
      }
    });

    slides.forEach(function(slide,index){
      var foot=slide.querySelector('.slide-footer');
      if(foot) foot.textContent='Slide '+(index+1);
      var num=slide.querySelector('.slide-num');
      if(num && /slide|ian\s*603/i.test(num.textContent||'')) num.textContent='Slide '+(index+1);
    });

    sync();
  }

  function init(){
    if(document.body.classList.contains('ian603-shell')) return;
    document.body.classList.add('ian603-shell');
    setupHeader();
    setupFooter();
    setupSlideProgress();
  }

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',init,{once:true});
  }else{
    init();
  }
})();
