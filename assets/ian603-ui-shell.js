
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
    }else{
      progressBtn=el('span','control shell-progress-action shell-generic-progress','Progress 0%');
      progressBtn.id='shellGenericProgress';
      actions.appendChild(progressBtn);
    }

    var runBtn=document.getElementById('runSlideBtn');
    if(runBtn){
      runBtn.classList.add('shell-run-action');
      runBtn.textContent='Run SQL';
      actions.appendChild(runBtn);
    }else{
      runBtn=el('button','control shell-run-action','Run SQL');
      runBtn.type='button';
      runBtn.id='shellRunBtn';
      runBtn.disabled=true;
      runBtn.addEventListener('click',function(){
        var slide=document.querySelector('.slide.active');
        if(!slide) return;
        var target=[].slice.call(slide.querySelectorAll('button')).find(function(btn){
          var label=(btn.textContent||'').replace(/\\s+/g,' ').trim();
          return btn!==runBtn && !btn.disabled && /^(Run|Run SQL|Run & Check)$/i.test(label);
        });
        if(target) target.click();
      });
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
      var select=document.getElementById('slideSelect');
      if(select && select.selectedIndex>=0) return select.selectedIndex;
      var idx=slides.findIndex(function(slide){return slide.classList.contains('active');});
      if(idx>=0) return idx;
      return 0;
    }

    function sync(){
      var idx=activeIndex();
      var select=document.getElementById('slideSelect');
      var total=(select && select.options && select.options.length) || slides.length || 1;
      var num=idx+1;
      var pct=Math.max(1,Math.round((num/total)*100));
      if(statusText) statusText.textContent='Slide '+num+'/'+total;
      if(statusPct) statusPct.textContent=pct+'%';

      var genericProgress=document.getElementById('shellGenericProgress');
      if(genericProgress) genericProgress.textContent='Progress '+pct+'%';

      var shellRun=document.getElementById('shellRunBtn');
      if(shellRun){
        var active=slides[idx];
        var target=active ? [].slice.call(active.querySelectorAll('button')).find(function(btn){
          var label=(btn.textContent||'').replace(/\\s+/g,' ').trim();
          return !btn.disabled && /^(Run|Run SQL|Run & Check)$/i.test(label);
        }) : null;
        shellRun.disabled=!target;
        shellRun.textContent=target && /Check/i.test(target.textContent||'') ? 'Run & Check' : 'Run SQL';
      }
    }

    slides.forEach(function(slide){
      try{
        new MutationObserver(sync).observe(slide,{attributes:true,attributeFilter:['class']});
      }catch(e){}
    });

    var select=document.getElementById('slideSelect');
    if(select){
      select.addEventListener('change',function(){setTimeout(sync,0);});
      try{ new MutationObserver(sync).observe(select,{childList:true}); }catch(e){}
    }
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


  /* IAN603_SQL_FOCUS_SHARED_START */
  function setupSqlFocus(){
    var activeBox=null;
    var previousShellHeight='';

    function editorShell(box){
      return box.querySelector('.pgadmin-editor-shell,.pg-shell');
    }
    function editorTextarea(box){
      return box.querySelector('textarea.sql-editor,textarea.pg-editor');
    }
    function actionBar(box){
      return box.querySelector('.code-head .cell-actions,.pg-head .pg-actions,.sql-head .sql-actions');
    }
    function localButtonClass(box){
      if(box.classList.contains('pg-cell')) return 'pg-btn';
      if(box.classList.contains('sql-cell')) return 'sql-btn';
      return 'cell-btn';
    }
    function syncEditor(box){
      var ta=editorTextarea(box);
      if(!ta) return;
      ta.dispatchEvent(new Event('input',{bubbles:true}));
      ta.dispatchEvent(new Event('scroll'));
    }
    function closeFocus(){
      if(!activeBox) return;
      var box=activeBox;
      var shell=editorShell(box);
      var btn=box.querySelector('.sql-focus-toggle');

      box.classList.remove('ian603-sql-focus');
      document.body.classList.remove('sql-focus-open');

      if(shell){
        shell.style.height=previousShellHeight;
        requestAnimationFrame(function(){
          var ta=editorTextarea(box);
          if(ta && box.classList.contains('code-cell')){
            shell.style.height=Math.max(190,ta.offsetHeight)+'px';
          }
          syncEditor(box);
        });
      }

      if(btn){
        btn.textContent='Expand';
        btn.setAttribute('aria-label','Expand SQL editor');
        btn.setAttribute('aria-pressed','false');
        btn.title='Open a larger SQL workspace';
      }

      activeBox=null;
      previousShellHeight='';
    }
    function openFocus(box){
      if(activeBox && activeBox!==box) closeFocus();

      var shell=editorShell(box);
      var ta=editorTextarea(box);
      var btn=box.querySelector('.sql-focus-toggle');

      previousShellHeight=shell ? shell.style.height : '';
      activeBox=box;
      box.classList.add('ian603-sql-focus');
      document.body.classList.add('sql-focus-open');

      if(btn){
        btn.textContent='Collapse';
        btn.setAttribute('aria-label','Collapse SQL editor');
        btn.setAttribute('aria-pressed','true');
        btn.title='Return to the regular slide view';
      }

      requestAnimationFrame(function(){
        if(ta){
          try{ ta.focus({preventScroll:true}); }catch(e){ ta.focus(); }
          syncEditor(box);
        }
      });
    }
    function enhanceBox(box){
      if(box.dataset.ian603SqlFocus==='ready') return;
      var ta=editorTextarea(box);
      var actions=actionBar(box);
      if(!ta) return;

      if(!actions){
        var head=box.querySelector('.code-head,.pg-head,.sql-head');
        if(head){
          actions=el('div',box.classList.contains('sql-cell')?'sql-actions':(box.classList.contains('pg-cell')?'pg-actions':'cell-actions'));
          head.appendChild(actions);
        }
      }
      if(!actions) return;

      box.dataset.ian603SqlFocus='ready';

      // Respect a module-specific expand control if one already exists.
      var existing=actions.querySelector('.sql-focus-toggle,.sql-expand');
      if(existing){
        existing.classList.add('sql-focus-toggle');
        return;
      }

      var btn=el('button',localButtonClass(box)+' sql-focus-toggle','Expand');
      btn.type='button';
      btn.setAttribute('aria-label','Expand SQL editor');
      btn.setAttribute('aria-pressed','false');
      btn.title='Open a larger SQL workspace';
      btn.addEventListener('click',function(){
        if(box.classList.contains('ian603-sql-focus')) closeFocus();
        else openFocus(box);
      });
      actions.appendChild(btn);
    }

    function scan(){
      [].slice.call(document.querySelectorAll('.code-cell,.pg-cell,.sql-cell')).forEach(enhanceBox);
    }

    scan();

    // Some modules generate SQL cells dynamically.
    try{
      new MutationObserver(function(mutations){
        var needsScan=mutations.some(function(m){return m.addedNodes && m.addedNodes.length;});
        if(needsScan) scan();
      }).observe(document.body,{childList:true,subtree:true});
    }catch(e){}

    document.addEventListener('keydown',function(event){
      if(event.key==='Escape' && activeBox){
        event.preventDefault();
        event.stopPropagation();
        closeFocus();
      }
    },true);
  }
  /* IAN603_SQL_FOCUS_SHARED_END */

  function init(){
    if(document.body.classList.contains('ian603-shell')) return;
    document.body.classList.add('ian603-shell');
    setupHeader();
    setupFooter();
    setupSlideProgress();
    setupSqlFocus();
  }

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',init,{once:true});
  }else{
    init();
  }
})();
