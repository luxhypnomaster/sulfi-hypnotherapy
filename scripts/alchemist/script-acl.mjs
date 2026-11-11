// The access decision uses the complete permission list, not the Files.shared
// summary flag. This matches the existing runtime Drive.Permissions.list gate.
export function scriptAclDecision(file,permissions,pages,ownerEmail){
 const ownerOnly=file?.trashed!==true&&file?.owners?.length===1&&file.owners[0].emailAddress===ownerEmail&&permissions.length===1&&permissions[0].type==='user'&&permissions[0].role==='owner'&&permissions[0].emailAddress===ownerEmail;
 return {readable:true,completePermissions:true,permissionPages:pages,permissionCount:permissions.length,sharedSummaryFlag:file.shared===true,ownerOnly,privateVerified:ownerOnly};
}
export async function readScriptAcl(client,id,ownerEmail){
 const base='https://www.googleapis.com/drive/v3/files/'+encodeURIComponent(id);
 const file=(await client.request({url:base,params:{fields:'shared,trashed,owners(emailAddress)'}})).data;
 let token,pages=0;const permissions=[],seen=new Set();
 do{if(++pages>20)throw Error('SCRIPT_ACL_PAGE_LIMIT');const result=(await client.request({url:base+'/permissions',params:{fields:'permissions(type,role,emailAddress),nextPageToken',pageSize:100,...(token?{pageToken:token}:{})}})).data;
  if(!Array.isArray(result.permissions))throw Error('SCRIPT_ACL_INCOMPLETE');permissions.push(...result.permissions);token=result.nextPageToken;
  if(token){if(seen.has(token))throw Error('SCRIPT_ACL_CURSOR_LOOP');seen.add(token);}
 }while(token);
 return scriptAclDecision(file,permissions,pages,ownerEmail);
}
