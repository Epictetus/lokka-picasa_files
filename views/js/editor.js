$(function() {
  var editor = $('textarea.editor').cleditor()[0];
  var org_width = editor.options.width;
  var org_height = editor.options.height;
  var new_controls = editor.options.controls.replace("image", "image upload_files");

  editor.$area.insertBefore(editor.$main);  // Move the textarea out of the main div 
  editor.$area.removeData("cleditor");      // Remove the cleditor pointer from the textarea
  editor.$main.remove();                    // Remove the main div and all children from the DOM

  $('textarea.editor').cleditor({
    width:    org_width,
    height:   org_height,
    controls: new_controls
  });
})
