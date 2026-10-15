import { PGlite } from "https://cdn.jsdelivr.net/npm/@electric-sql/pglite/dist/index.js";
let db;
function send(id,payload){self.postMessage({id,...payload})}
function shape(r){return {columns:r.fields?.map(f=>f.name)||Object.keys(r.rows?.[0]||{}),rows:(r.rows||[]).slice(0,200).map(x=>Object.fromEntries(Object.entries(x).map(([k,v])=>[k,typeof v==="bigint"?String(v):v]))),total:r.rows?.length??0,affectedRows:r.affectedRows||0}}
function normalizeValue(x){if(x===null)return null;if(typeof x==="number")return Number(x.toPrecision(12));if(x instanceof Date)return x.toISOString();if(typeof x==="bigint")return x.toString();if(Array.isArray(x))return x.map(normalizeValue);if(x&&typeof x==="object")return Object.fromEntries(Object.keys(x).sort().map(k=>[k,normalizeValue(x[k])]));return x}
function compare(a,b,ordered){const ac=a.fields?.map(x=>x.name)||[],bc=b.fields?.map(x=>x.name)||[];if(JSON.stringify(ac)!==JSON.stringify(bc))return {correct:false,reason:"Column names or column order differ from the expected output."};let ar=(a.rows||[]).map(x=>JSON.stringify(normalizeValue(x))),br=(b.rows||[]).map(x=>JSON.stringify(normalizeValue(x)));if(!ordered){ar.sort();br.sort()}return {correct:JSON.stringify(ar)===JSON.stringify(br),reason:ar.length!==br.length?"The number of returned rows differs.":"The returned values differ from the expected output."}}
async function guarded(sql){
 const text=String(sql||"").trim();
 if(!/^(SELECT|WITH|VALUES|EXPLAIN)\b/i.test(text))throw Error("This playground is read-only. Start with SELECT, WITH, VALUES, or EXPLAIN.");
 await db.exec("BEGIN READ ONLY; SET LOCAL statement_timeout = '4000ms';");
 try{const result=await db.query(text);return result}finally{try{await db.exec("ROLLBACK")}catch(e){}}
}
async function boot(){
 const response=await fetch("s_interview_dataset.sql",{cache:"no-store"});
 if(!response.ok)throw Error("Could not load the practice dataset: HTTP "+response.status);
 db=new PGlite();
 await db.exec(await response.text());
 send("boot",{ready:true})
}
boot().catch(e=>send("boot",{error:e.message||String(e)}));
self.onmessage=async({data})=>{
 const {id,action,sql,reference,ordered}=data;
 try{
 if(!db)throw Error("PostgreSQL is still loading.");
 if(action==="run"){const r=await guarded(sql);send(id,{ok:true,result:shape(r)})}
 if(action==="check"){
  const student=await guarded(sql);
  let verdict;
  if(/^\s*EXPLAIN\b/i.test(reference||""))verdict={correct:/^\s*EXPLAIN\s+(?:ANALYZE\s+)?/i.test(sql)&&(/^\s*EXPLAIN\s+ANALYZE/i.test(sql)===/^\s*EXPLAIN\s+ANALYZE/i.test(reference)),reason:"This task validates plan-execution syntax rather than comparing variable plan output."};
  else{const expected=await guarded(reference);verdict=compare(student,expected,Boolean(ordered))}
  send(id,{ok:true,result:shape(student),...verdict});
 }
 }catch(e){send(id,{ok:false,error:e?.message||String(e)})}
};
