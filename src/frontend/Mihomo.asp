<!DOCTYPE html>
<html lang="en">
<head>
<!--page:mihomo-->
<meta http-equiv="X-UA-Compatible" content="IE=Edge">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Cache-Control" content="no-cache">
<meta http-equiv="Expires" content="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<link rel="stylesheet" type="text/css" href="/js/table/table.css">
<link rel="stylesheet" type="text/css" href="/ext/mihomo/app.css">
<title>Mihomo</title>
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/js/httpApi.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/validator.js"></script>
<script>
window.MIHOMO_API_ORIGIN = window.location.protocol + "//" + window.location.hostname + ":5581";
window.MIHOMO_ROUTER_LANGUAGE = '<% nvram_get("preferred_lang"); %>';
</script>
</head>
<body>
<div id="app"></div>
<script type="module" src="/ext/mihomo/app.js"></script>
</body>
</html>
