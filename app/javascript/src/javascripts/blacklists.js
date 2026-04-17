import Filter from "./models/Filter";
import PostCache from "./models/PostCache";
import Utility from "./utility";
import LStorage from "./utility/storage";

let Blacklist = {};

Blacklist.isAnonymous = false;
Blacklist.filters = {};

Blacklist.hiddenPosts = new Set();
Blacklist.matchedPosts = new Set();

Blacklist.ui = [];

/** Import the anonymous blacklist from the LocalStorage */
Blacklist.init_anonymous_blacklist = function () {
  let metaTag = $("meta[name=blacklisted-tags]");
  if (metaTag.length == 0)
    metaTag = $("<meta>")
      .attr({
        name: "blacklisted-tags",
        content: "[]",
      })
      .appendTo("head");

  if ($("body").data("user-is-anonymous")) {
    Blacklist.isAnonymous = true;
    metaTag.attr("content", LStorage.Blacklist.AnonymousBlacklist);
  }
};

/** Set up the modal dialogue with the blacklist editor */
Blacklist.init_blacklist_editor = function () {
  let windowWidth = $(window).width(),
    windowHeight = $(window).height();
  $("#blacklist-edit-dialog").dialog({
    autoOpen: false,
    width: windowWidth > 400 ? 400 : windowWidth,
    height: windowHeight > 400 ? 400 : windowHeight,
  });

  $("#blacklist-cancel").on("click", function () {
    $("#blacklist-edit-dialog").dialog("close");
  });

  $("#blacklist-save").on("click", function () {
    const blacklist_content = $("#blacklist-edit").val();
    const blacklist_json = JSON.stringify(blacklist_content.split(/\n\r?/));
    if (Blacklist.isAnonymous) {
      LStorage.Blacklist.AnonymousBlacklist = blacklist_json;
    } else {
      $.ajax("/users/update.json", {
        method: "POST",
        data: {
          "user[blacklisted_tags]": blacklist_content,
        },
      }).done(function () {
        Utility.notice("Blacklist updated");
      }).fail(function () {
        Utility.error("Failed to update blacklist");
      });
    }

    $("#blacklist-edit-dialog").dialog("close");
    $("meta[name=blacklisted-tags]").attr("content", blacklist_json);

    // Start from scratch
    Blacklist.regenerate_filters();
    Blacklist.add_posts(PostCache.sample());
    Blacklist.update_visibility();
  });

  $("#blacklist-edit-link").on("click", function (event) {
    event.preventDefault();
    let entries = JSON.parse(Utility.meta("blacklisted-tags") || "[]");
    $("#blacklist-edit").val(entries.join("\n"));
    $("#blacklist-edit-dialog").dialog("open");
  });
};

/** Reveals the blacklisted post without disabling any filters */
Blacklist.init_reveal_on_click = function () {
  if (!$("#c-posts #a-show").length) return;
  $("#image-container").on("click", (event) => {
    $(event.currentTarget).removeClass("blacklisted");
  });
};

/** Import the blacklist from the meta tag */
Blacklist.regenerate_filters = function () {
  Blacklist.filters = {};

  // Attempt to create filters from text
  let blacklistText;
  try {
    blacklistText = JSON.parse(Utility.meta("blacklisted-tags") || "[]");
  } catch (error) {
    console.error(error);
    blacklistText = [];
  }

  for (let entry of blacklistText) {
    const line = Filter.create(entry);
    if (line) Blacklist.filters[line.text] = line;
  }

  // Clear any FilterState entries that don't have a matching filter
  const keys = Object.keys(Blacklist.filters);
  for (const filterState of LStorage.Blacklist.FilterState) {
    if (keys.includes(filterState)) continue;
    LStorage.Blacklist.FilterState.delete(filterState);
  }
};

/** Hides all comments created by blacklisted users */
Blacklist.init_comment_blacklist = function () {
  if (Utility.meta("blacklist-users") !== "true") return;

  // This is extraordinarily silly
  // We need a proper user ignoring system
  for (const filter of Object.values(Blacklist.filters)) {

    // Only the first token is accepted
    // If the user is trying something wackier, that's their fault
    if (!filter.tokens.length) continue;
    const token = filter.tokens[0];

    switch (token.type) {
      case "uploader": {
        if (token.uploaderID !== undefined) {
          $(`article[data-uploader-id="${token.uploaderID}"]`).hide();
          break;
        }
        $(`article[data-uploader="${token.value}"]`).hide();
        break;
      }
      case "uploaderid": {
        $(`article[data-uploader-id="${token.value}"]`).hide();
        break;
      }
    }
  }
};

/** Build the sidebar and inline blacklist toggles */
Blacklist.init_blacklist_toggles = function () {
  if (Blacklist.ui.length) return;

  $(".blacklist-ui").each((index, element) => {
    Blacklist.ui.push(new BlacklistUI($(element)));
  });
};

/**
 * Register posts in the system, and calculate which filters apply to them
 * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $posts Posts to register
 */
Blacklist.add_posts = function ($posts) {
  PostCache.register($posts);

  for (const filter of Object.values(Blacklist.filters))
    filter.update($posts);
};

/**
 * Recalculate hidden posts based on the current filters.
 * Also applies or removed `blacklist` class wherever necessary.
 */
Blacklist.update_visibility = function () {
  const oldPosts = this.hiddenPosts;
  let newPosts = [];

  // Tally up the new blacklisted posts
  for (const filter of Object.values(Blacklist.filters)) {
    if (!filter.enabled) continue;
    newPosts = newPosts.concat(Array.from(filter.matchIDs));
  }

  // Calculate diffs with sets so we don't rescan the full list for every post.
  this.hiddenPosts = new Set(newPosts.filter((n) => n));
  const added = [...this.hiddenPosts].filter((n) => !oldPosts.has(n));
  const removed = [...oldPosts].filter((n) => !this.hiddenPosts.has(n));

  // Update the UI
  for (const ui of Blacklist.ui) ui.rebuildFilters();

  // Apply / remove classes using the cached thumbnail elements in PostCache.
  for (const postID of added)
    PostCache.apply(postID, ($element) => {
      $element.addClass("blacklisted").trigger("blk:hide");
    });
  for (const postID of removed)
    PostCache.apply(postID, ($element) => {
      $element.removeClass("blacklisted").trigger("blk:show");
    });
};

/**
 * Adds a `filter-matches` class to any thumbnails that match any of the filters,
 * including disabled ones. Only needs to run after new posts get added to the page.
 */
Blacklist.update_styles = function () {
  let allPosts = [];
  for (const filter of Object.values(Blacklist.filters))
    allPosts = allPosts.concat(Array.from(filter.matchIDs));
  Blacklist.matchedPosts = new Set(allPosts);

  $(".filter-matches").removeClass("filter-matches");
  for (const postID of Blacklist.matchedPosts)
    PostCache.apply(postID, ($element) => {
      $element.addClass("filter-matches");
    });
};

$(() => {
  Blacklist.init_anonymous_blacklist();
  Blacklist.init_blacklist_editor();
  Blacklist.init_reveal_on_click();

  Blacklist.regenerate_filters();
  Blacklist.add_posts($(".blacklistable"));
  Blacklist.update_styles();
  Blacklist.update_visibility();
  $("#blacklisted-hider").remove();

  Blacklist.init_comment_blacklist();
  Blacklist.init_blacklist_toggles();

  // Pause videos when blacklisting
  // This seems extraordinarily uncommon, so it's here
  // just for feature parity with the old blacklist.
  if ($("#c-posts #a-show").length > 0) return;
  let container = $("#image-container[data-file-ext='webm'], #image-container[data-file-ext='mp4']").on("blk:hide", () => {
    const video = container.find("video");
    if (!video.length) return;
    video[0].pause();
  });
});

/**
 * Represents the list of toggles for the blacklist filters.
 * Could be either in a sidebar or inline formats.
 */
class BlacklistUI {
  /**
   * Constructor.
   * Should only be run on `.blacklist-ui` elements.
   * @param {JQuery<HTMLDivElement>} $element
   */
  constructor ($element) {
    this.$element = $element;
    this.$counter = $element.find(".blacklisted-count");

    this.post = parseInt($element.attr("post"));
    this.hasPost = !Number.isNaN(this.post);

    // Collapsable header
    $element
      .attr("collapsed", LStorage.Blacklist.Collapsed)
      .find(".blacklist-header")
      .on("click", () => {
        const newState = this.$element.attr("collapsed") !== "true";
        this.$element.attr("collapsed", newState);
        LStorage.Blacklist.Collapsed = newState;
      });

    // Toggle All switch
    this.$toggle = $element
      .find(".blacklist-toggle-all")
      .text("Disable All Filters")
      .on("click", () => {
        if (this.$toggle.attr("is-enabling") == "true") {
          for (const filter of Object.values(Blacklist.filters))
            filter._enabled = true;
          LStorage.Blacklist.FilterState.clear();
        } else {
          const filterList = new Set();
          for (const filter of Object.values(Blacklist.filters)) {
            filter._enabled = false;
            filterList.add(filter.text);
          }
          LStorage.Blacklist.FilterState = filterList;
        }

        for (const element of Blacklist.ui) element.rebuildFilters();
        Blacklist.update_visibility();
      });

    // Filters
    this.$container = $($element.find(".blacklist-filters"));
    this.rebuildFilters();
  }

  /**
   * Deletes and re-creates the filter list.
   * Done automatically every time a filter gets turned on or off,
   * so all instances are in sync no matter what.
   */
  rebuildFilters () {
    this.$container.html("");

    let activeFilters = 0,
      inactiveFilters = 0;
    for (const [name, filter] of Object.entries(Blacklist.filters)) {
      if (filter.matchIDs.size === 0) continue;

      // Special case for the posts/show page sidebar
      if (this.hasPost && !filter.matchIDs.has(this.post))
        continue;

      activeFilters++;
      if (!filter.enabled) inactiveFilters++;

      const entry = $("<li>")
        .attr("enabled", filter.enabled)
        .on("click", () => {
          // Actual toggling done elsewhere
          filter.enabled = !filter.enabled;
        })
        .appendTo(this.$container);

      const link = $("<a>")
        .attr("href", "/posts?tags=" + encodeURIComponent(name))
        .html(name
          .replace(/_/g, "&#8203;_") // Allow tags to linebreak on underscores
          .replace(/ -/, " &#8209;"), // Prevent linebreaking on negated tags
        )
        .on("click", (event) => {
          event.preventDefault();
          // Link is disabled, but could still be right-clicked
        })
        .appendTo(entry);

      $("<span>").text(filter.matchIDs.size).appendTo(link);
    }

    // Update the total blacklist size
    this.$element.attr("filters", activeFilters);
    this.$counter.text("(" + Blacklist.hiddenPosts.size + ")");

    // Change the toggle state accordingly
    this.$toggle
      .text(inactiveFilters ? "Enable All Filters" : "Disable All Filters")
      .attr("is-enabling", inactiveFilters > 0);
  }
}

export default Blacklist;
