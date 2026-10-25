// Supabase 项目配置。国内直连不了 supabase.co，所以在 Netlify 上走同域的 /sb 转发（见 _redirects）；
// 转发不支持实时推送，改为定时刷新。anon key 本来就是公开的，安全由数据库里的权限规则保证。
(function(){
  const direct = "https://clqqhpjwsbtfnyedlvjt.supabase.co";
  const proxied = !/github\.io$|^localhost$|^127\./.test(location.hostname);
  window.TSY_CONFIG = {
    url: proxied ? location.origin + "/sb" : direct,
    key: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNscXFocGp3c2J0Zm55ZWRsdmp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5Mzg4NTEsImV4cCI6MjEwODUxNDg1MX0.6cqFO6xHK7TRE82ISGL2fhEsqvNwR7Wg44jnMaTIQGI",
    realtime: !proxied,
  };
})();
