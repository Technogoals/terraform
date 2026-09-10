'use strict';
const canvas = document.querySelector('#board');
const ctx = canvas.getContext('2d');
const overlay = document.querySelector('#overlay');
const startButton = document.querySelector('#start');
const pauseButton = document.querySelector('#pause');
const pace = document.querySelector('#pace');
const status = document.querySelector('#status');
const vectors = {up: {x:0,y:-1}, down:{x:0,y:1}, left:{x:-1,y:0}, right:{x:1,y:0}};
const size = 20, cell = canvas.width / size;
let snake, food, direction, queued, score, timer, state = 'ready', best = 0;
try { best = Math.max(0, Number(localStorage.getItem('aiinc-snake-best')) || 0); } catch (_) {}
document.querySelector('#best').textContent = best;
function placeFood() {
  const empty = [];
  for (let y=0;y<size;y++) for(let x=0;x<size;x++)
    if (!snake.some(p=>p.x===x && p.y===y)) empty.push({x,y});
  return empty.length ? empty[Math.floor(Math.random()*empty.length)] : null;
}
function draw() {
  ctx.fillStyle='#0c1711'; ctx.fillRect(0,0,600,600);
  ctx.strokeStyle='#1c2b20'; ctx.lineWidth=1;
  for(let i=0;i<=size;i++){ctx.beginPath();ctx.moveTo(i*cell,0);ctx.lineTo(i*cell,600);ctx.moveTo(0,i*cell);ctx.lineTo(600,i*cell);ctx.stroke();}
  if(food){ctx.fillStyle='#ff9377';ctx.beginPath();ctx.arc((food.x+.5)*cell,(food.y+.5)*cell,cell*.29,0,Math.PI*2);ctx.fill();}
  snake.forEach((p,i)=>{ctx.fillStyle=i===0?'#e2ffa0':'#a4ce58';ctx.fillRect(p.x*cell+2,p.y*cell+2,cell-4,cell-4);});
  const head=snake[0], v=vectors[direction], px=-v.y, py=v.x;
  ctx.fillStyle='#142015';
  [-1,1].forEach(side=>{ctx.beginPath();ctx.arc((head.x+.5)*cell+v.x*6+px*side*6,(head.y+.5)*cell+v.y*6+py*side*6,2.5,0,Math.PI*2);ctx.fill();});
}
function reset() {
  clearInterval(timer);snake=[{x:9,y:10},{x:8,y:10},{x:7,y:10}];direction='right';queued=null;score=0;
  document.querySelector('#score').textContent=score;food=placeFood();draw();
}
function show(title,hint,label){document.querySelector('#message').textContent=title;document.querySelector('#hint').textContent=hint;startButton.textContent=label;overlay.hidden=false;}
function finish(won=false){clearInterval(timer);state='over';pace.disabled=false;pauseButton.disabled=true;status.textContent=won?'Board complete!':'Game over. Try for a new best.';show(won?'You filled the board!':'One more round?',`Score ${score} · Personal best ${best}`,'Play again ↗');startButton.focus();}
function tick(){
  if(queued){direction=queued;queued=null;}
  const v=vectors[direction], head={x:snake[0].x+v.x,y:snake[0].y+v.y};
  const eating=food && head.x===food.x && head.y===food.y;
  const body=eating?snake:snake.slice(0,-1);
  if(head.x<0||head.x>=size||head.y<0||head.y>=size||body.some(p=>p.x===head.x&&p.y===head.y)){finish();return;}
  snake.unshift(head);
  if(eating){score+=10;document.querySelector('#score').textContent=score;
    if(score>best){best=score;document.querySelector('#best').textContent=best;try{localStorage.setItem('aiinc-snake-best',String(best));}catch(_){}}
    food=placeFood();
  }else snake.pop();
  draw();if(!food)finish(true);
}
function resume(){state='running';overlay.hidden=true;pauseButton.disabled=false;pauseButton.textContent='Pause';pace.disabled=true;status.textContent='Find the next bite. Avoid walls and your tail.';clearInterval(timer);timer=setInterval(tick,Number(pace.value));canvas.focus();}
function pause(){if(state!=='running')return;clearInterval(timer);state='paused';pauseButton.textContent='Resume';status.textContent='Paused. Take your time.';show('Take a breather.','Your next bite can wait.','Resume ↗');}
function turn(next){if(state!=='running'||queued)return;const a=vectors[direction],b=vectors[next];if(a.x+b.x===0&&a.y+b.y===0)return;queued=next;}
startButton.addEventListener('click',()=>{if(state!=='paused')reset();resume();});
pauseButton.addEventListener('click',()=>state==='running'?pause():state==='paused'&&resume());
const keys={ArrowUp:'up',w:'up',ArrowDown:'down',s:'down',ArrowLeft:'left',a:'left',ArrowRight:'right',d:'right'};
document.addEventListener('keydown',event=>{
  if(event.target.tagName==='SELECT'||event.target.tagName==='BUTTON')return;
  const key=event.key.length===1?event.key.toLowerCase():event.key;
  if(keys[key]){if(state==='running'){event.preventDefault();turn(keys[key]);}}
  else if(event.code==='Space'&&(state==='running'||state==='paused')){event.preventDefault();state==='running'?pause():resume();}
});
document.querySelectorAll('[data-dir]').forEach(button=>button.addEventListener('click',()=>{turn(button.dataset.dir);canvas.focus();}));
let touch=null;
canvas.addEventListener('pointerdown',e=>{touch={x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId);});
canvas.addEventListener('pointerup',e=>{if(!touch)return;const dx=e.clientX-touch.x,dy=e.clientY-touch.y;touch=null;if(Math.max(Math.abs(dx),Math.abs(dy))<12)return;turn(Math.abs(dx)>Math.abs(dy)?(dx>0?'right':'left'):(dy>0?'down':'up'));});
canvas.addEventListener('pointercancel',()=>{touch=null;});
document.addEventListener('visibilitychange',()=>{if(document.hidden)pause();});
window.addEventListener('blur',pause);
reset();
