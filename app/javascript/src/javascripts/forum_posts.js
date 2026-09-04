import Utility from "./utility";

let ForumPost = {};

ForumPost.initialize_all = function () {
  if ($("#c-forums-topics #a-show,#c-forums-posts #a-show").length) {
    $(".edit_forum_post_link").on("click.danbooru", function (e) {
      var link_id = $(this).attr("id");
      var forum_post_id = link_id.match(/^edit_forum_post_link_(\d+)$/)[1];
      $("#edit_forum_post_" + forum_post_id).fadeToggle("fast");
      e.preventDefault();
    });

    $(".edit_forum_topic_link").on("click.danbooru", function (e) {
      var link_id = $(this).attr("id");
      var forum_topic_id = link_id.match(/^edit_forum_topic_link_(\d+)$/)[1];
      $("#edit_forum_topic_" + forum_topic_id).fadeToggle("fast");
      e.preventDefault();
    });

    $(".forum-post-reply-link").on("click", ForumPost.quote);
    $(".forum-post-hide-link").on("click", ForumPost.hide);
    $(".forum-post-unhide-link").on("click", ForumPost.unhide);
    $("#subnav-lock-link").on("click", ForumPost.lock);
  }
};

ForumPost.reinitialize_all = function () {
  if ($("#c-forums-topics #a-show,#c-forums-posts #a-show").length) {
    $(".edit_forum_post_link").off("click.danbooru");
    $(".edit_forum_topic_link").off("click.danbooru");
    $(".forum-post-reply-link").off("click");
    $(".forum-post-hide-link").off("click");
    $(".forum-post-unhide-link").off("click");
    $("#subnav-lock-link").off("click");
    this.initialize_all();
  }
};

ForumPost.quote = function (e) {
  e.preventDefault();
  const parent = $(e.target).parents("article.forum-post");
  const fpid = parent.data("forum-post-id");
  $.ajax({
    url: `/forums/posts/${fpid}.json`,
    type: "GET",
    dataType: "json",
    accept: "text/javascript",
  }).done(function (data) {
    let stripped_body = data.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, "");
    stripped_body = `[quote]@${parent.data("creator")} said:
${stripped_body}
[/quote]

`;
    var $textarea = $("#forum_post_body_for_");
    var msg = stripped_body;
    if ($textarea.val().length > 0) {
      msg = $textarea.val() + "\n\n" + msg;
    }

    $textarea.val(msg);
    $textarea.selectEnd();
    $("#topic-response").show();
    setTimeout(function () {
      $("#topic-response")[0].scrollIntoView();
    }, 15);
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

ForumPost.hide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to hide this post?"))
    return;
  const parent = $(e.target).parents("article.forum-post");
  const fpid = parent.data("forum-post-id");
  $.ajax({
    url: `/forums/posts/${fpid}/hide.json`,
    type: "PUT",
    dataType: "json",
  }).done(function () {
    $(`.forum-post[data-forum-post-id="${fpid}"] div.author h4`).append(" (hidden)");
    $(`.forum-post[data-forum-post-id="${fpid}"]`).attr("data-is-hidden", "true");
  }).fail(function (data) {
    const message = Object.values(data.responseJSON.errors).join("; ");
    Utility.error(`Failed to hide post: ${message}`);
  });
};

ForumPost.unhide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to unhide this post?"))
    return;
  const parent = $(e.target).parents("article.forum-post");
  const fpid = parent.data("forum-post-id");
  $.ajax({
    url: `/forums/posts/${fpid}/unhide.json`,
    type: "PUT",
    dataType: "json",
  }).done(function () {
    const $author = $(`.forum-post[data-forum-post-id="${fpid}"] div.author h4`);
    $author.text($author.text().replace(" (hidden)", ""));
    $(`.forum-post[data-forum-post-id="${fpid}"]`).attr("data-is-hidden", "false");
  }).fail(function () {
    Utility.error("Failed to unhide post.");
  });
};

ForumPost.lock = function (e) {
  e.preventDefault();
  const reason = prompt("Reason for locking this topic (optional):");
  if (reason === null) return;
  const ftid = $(e.target).data("tid");
  $.ajax({
    url: `/forums/topics/${ftid}/lock.json`,
    type: "PUT",
    data: { lock_reason: reason },
    dataType: "json",
  }).done(function () {
    location.reload();
  }).fail(function () {
    Utility.error("Failed to lock topic.");
  });
};

$(document).ready(function () {
  ForumPost.initialize_all();
});

export default ForumPost;
