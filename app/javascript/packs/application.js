/* eslint no-console:0 */
/* global require */

function importAll (r) {
  r.keys().forEach(r);
}

export { default as $ } from "jquery";

import Rails from "@rails/ujs";
Rails.start();
var iMadeAMistakeAndNeedToFixIt = 0;

require("jquery-hotkeys");

require("jquery-ui/ui/widgets/autocomplete");
require("jquery-ui/ui/widgets/button");
require("jquery-ui/ui/widgets/dialog");
require("jquery-ui/ui/widgets/draggable");
require("jquery-ui/ui/widgets/sortable");
require("jquery-ui/ui/widgets/resizable");
require("jquery-ui/themes/base/core.css");
require("jquery-ui/themes/base/autocomplete.css");
require("jquery-ui/themes/base/button.css");
require("jquery-ui/themes/base/dialog.css");
require("jquery-ui/themes/base/draggable.css");
require("jquery-ui/themes/base/sortable.css");
require("jquery-ui/themes/base/resizable.css");
require("jquery-ui/themes/base/theme.css");

require("../src/styles/base.scss");

importAll(require.context("../src/javascripts", true, /\.js(\.erb)?$/));

require.context("../../../public/images", true);

export { default as Autocomplete } from "../src/javascripts/autocomplete.js.erb";
export { default as Blacklist } from "../src/javascripts/blacklists.js";
export { default as Block } from "../src/javascripts/blocks.js";
export { default as Comment } from "../src/javascripts/comments.js";
export { default as CurrentUser } from "../src/javascripts/models/CurrentUser.js";
export { default as DText } from "../src/javascripts/dtext.js";
export { default as MFA } from "../src/javascripts/mfa.js";
export { default as Note } from "../src/javascripts/notes.js";
export { default as Notification } from "../src/javascripts/notifications.js";
export { default as Post } from "../src/javascripts/posts.js";
export { default as PostDeletion } from "../src/javascripts/post_delete.js";
export { default as PostDeletionReasons } from "../src/javascripts/post_deletion_reasons.js";
export { default as PostModeMenu } from "../src/javascripts/post_mode_menu.js";
export { default as PostReplacement } from "../src/javascripts/post_replacement.js";
export { default as PostReplacementRejection } from "../src/javascripts/post_replacement_reject.js";
export { default as PostReplacementRejectionReasons } from "../src/javascripts/post_replacement_rejection_reasons.js";
export { default as PostVersions } from "../src/javascripts/post_versions.js";
export { default as RecordBuilder } from "../src/javascripts/record_builder.js";
export { default as Replacer } from "../src/javascripts/replacer.js";
export { default as Rules } from "../src/javascripts/rules.js";
export { default as Shortcuts } from "../src/javascripts/shortcuts.js";
export { default as StaffNote } from "../src/javascripts/staff_notes.js";
export { default as Utility } from "../src/javascripts/utility.js";
export { default as TagRelationships } from "../src/javascripts/tag_relationships.js";
export { default as Takedown } from "../src/javascripts/takedowns.js";
export { default as Theme } from "../src/javascripts/themes.js";
export { default as Thumbnails } from "../src/javascripts/thumbnails.js";
export { default as Tickets } from "../src/javascripts/tickets.js";
export { default as Uploader } from "../src/javascripts/uploader.js";
export { default as VoteManager } from "../src/javascripts/vote_manager.js";
export { default as HoverZoom } from "../src/javascripts/hover_zoom.js";

function inError (msg) {
  $(window).trigger("danbooru:error", msg);
}

function inNotice (msg) {
  $(window).trigger("danbooru:notice", msg);
}

export {inError as error, inNotice as notice};
