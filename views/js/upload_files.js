$(function() {

  $.cleditor.buttons.upload_files = {
    name: "upload_files",
    image: "../../../plugin/lokka-picasa_files/views/upload_files.gif",
    title: "Picasa",
    command: "inserthtml",
    popupName: "upload_files",
    popupClass: "cleditorPrompt",
    popupContent: uploadFilesContent,
    buttonClick: uploadFilesClick
  };

  function uploadFilesContent() {
    var content = null;

    $.ajax({
      url: '/admin/plugins/picasa/files',
      async: false,
      success: function(data) { content = data; }
    });

    return content;
  }

  function uploadFilesClick(e, data) {
    var idHeader = "upload_file_";

    $.each($(data.popup).find("img.upload_file"), function() {
      var idAttr = $(this).attr('id');
      var id = idAttr.substring(idAttr.indexOf(idHeader) + idHeader.length);
      var thumbnails_url = $("input:hidden#" + idHeader + "thumbnails_url_" + id).val();
      $(this).attr("src", thumbnails_url);
    });

    $(data.popup).find("img.upload_file").unbind("click").bind("click", function() {
      var editor = data.editor;
      var idAttr = $(this).attr('id');
      var id = idAttr.substring(idAttr.indexOf(idHeader) + idHeader.length);
      var title = $(this).attr('alt');
      var url = $("input:hidden#" + idHeader + "url_" + id).val();
      var html = html = "<img src='" + url + "' alt='" + title + "'>";
      editor.execCommand(data.command, html, null, data.button);
      editor.hidePopups();
      editor.focus();
    });
  }
});
