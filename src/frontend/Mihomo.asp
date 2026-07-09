<!DOCTYPE html>
<html>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>Mihomo</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<script src="/state.js"></script>
<script src="/general.js"></script>
<script src="/popup.js"></script>
<script src="/help.js"></script>
<script>
function initial(){
    SetCurrentPage();
    show_menu();
    var preferredLang = document.getElementById("preferred_lang").value || "";
    var target = window.location.protocol + "//" + window.location.hostname + ":5581/?lang=" + encodeURIComponent(preferredLang);
    document.getElementById("mihomoFrame").src = target;
    document.getElementById("mihomoOpen").href = target;
}
function SetCurrentPage() {
    document.form.next_page.value = window.location.pathname.substring(1);
    document.form.current_page.value = window.location.pathname.substring(1);
}
</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
<form method="post" name="form" action="start_apply.htm" target="hidden_frame">
<input type="hidden" name="current_page" value="Mihomo.asp">
<input type="hidden" name="next_page" value="Mihomo.asp">
<input type="hidden" name="group_id" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_wait" value="5">
<input type="hidden" name="first_time" value="">
<input type="hidden" name="action_script" value="">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td align="left" valign="top">
<table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle">
<tr>
<td bgcolor="#4D595D" colspan="3" valign="top">
<div>&nbsp;</div>
<div class="formfonttitle">Mihomo</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
<div class="formfontdesc">
    Web interface is served by the Entware lighttpd service on port 5581.
    <a id="mihomoOpen" href="#" target="_blank" style="color:#FC0;">Open in a new tab</a>
</div>
<iframe id="mihomoFrame" style="width:100%;height:760px;border:0;background:#101820;border-radius:4px;"></iframe>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>
</table>
</form>
</body>
</html>
