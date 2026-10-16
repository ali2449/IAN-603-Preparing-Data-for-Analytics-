import { PGlite } from "https://cdn.jsdelivr.net/npm/@electric-sql/pglite/dist/index.js";
let db;
function send(id,payload){self.postMessage({id,...payload})}
function shape(r){return {columns:r.fields?.map(f=>f.name)||Object.keys(r.rows?.[0]||{}),rows:(r.rows||[]).slice(0,200).map(x=>Object.fromEntries(Object.entries(x).map(([k,v])=>[k,typeof v==="bigint"?String(v):v]))),total:r.rows?.length??0,affectedRows:r.affectedRows||0}}
function normalizeValue(x){if(x===null)return null;if(typeof x==="number")return Number(x.toPrecision(12));if(x instanceof Date)return x.toISOString();if(typeof x==="bigint")return x.toString();if(Array.isArray(x))return x.map(normalizeValue);if(x&&typeof x==="object")return Object.fromEntries(Object.keys(x).sort().map(k=>[k,normalizeValue(x[k])]));return x}
// Assess output data, not SQL capitalization, whitespace, line breaks, or clause formatting.
// PostgreSQL itself parses SQL keywords without regard to case. Compare output aliases
// case-insensitively and accept equivalent column order when labels are the same.
function compare(a,b,ordered){
 const ac=a.fields?.map(f=>f.name)||[];
 const bc=b.fields?.map(f=>f.name)||[];
 if(ac.length!==bc.length)return {correct:false,reason:"The number of result columns differs."};
 const used=new Set(),mapping=[];
 for(const col of bc){
  const found=ac.findIndex((name,i)=>!used.has(i)&&name.toLocaleLowerCase("en-US")===col.toLocaleLowerCase("en-US"));
  if(found<0)return {correct:false,reason:"Result column names do not match the requested columns or aliases. Letter case does not matter."};
  used.add(found);mapping.push(found);
 }
 function canonicalRows(r,columns,permutation){
  return (r.rows||[]).map(row=>JSON.stringify(permutation.map(i=>normalizeValue(row[columns[i]]))));
 }
 const student=canonicalRows(a,ac,mapping);
 const expected=canonicalRows(b,bc,bc.map((_,i)=>i));
 if(!ordered){student.sort();expected.sort();}
 const correct=JSON.stringify(student)===JSON.stringify(expected);
 const reason=student.length!==expected.length?"The number of returned rows differs.":"The query ran, but its output values differ from the expected results.";
 return {correct,reason:correct?"Query results match. SQL letter case and line formatting are ignored.":reason};
}
async function guarded(sql){
 const text=String(sql||"").trim();
 // Ignore introductory SQL comments when checking the permitted command.
 let executable=text;
 while(true){
  executable=executable.trimStart();
  if(executable.startsWith("--")){const end=executable.indexOf("\n");executable=end<0?"":executable.slice(end+1);continue;}
  if(executable.startsWith("/*")){const end=executable.indexOf("*/");executable=end<0?"":executable.slice(end+2);continue;}
  break;
 }
 if(!/^(SELECT|WITH|VALUES|EXPLAIN)\b/i.test(executable))throw Error("This playground is read-only. Begin with SELECT, WITH, VALUES, or EXPLAIN.");
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
