import {page} from "./utility/page";

let User = {};

User.initialize_tabs = function () {
  const container = $(".user-content");

  let selectedTab = "0";
  container.find("h2.tab").on("click", (event) => {
    event.preventDefault();

    let element = $(event.target);
    if (element.is("a")) element = element.parents("h2.tab");
    const newTab = element.attr("tab");
    if (newTab === selectedTab) return;

    container.find(`h2[tab="${selectedTab}"]`).removeClass("active");
    container.find(`div.tab-posts[tab="${selectedTab}"]`).addClass("hidden");

    container.find(`h2[tab="${newTab}"]`).addClass("active");
    container.find(`div.tab-posts[tab="${newTab}"]`).removeClass("hidden");
    container.attr("tab-active", newTab);

    selectedTab = newTab;
  });
};

User.initialize_permissions = function () {
  const $text = $("span.permissions-list");
  const $expand = $(".expand-permissions-link");
  const $collapse = $(".collapse-permissions-link");

  $expand.on("click", function (event) {
    event.preventDefault();
    $expand.hide();
    $collapse.show();
    $text.text($text.attr("data-full"));
  });

  $collapse.on("click", function (event) {
    event.preventDefault();
    $expand.show();
    $collapse.hide();
    $text.text($text.attr("data-short"));
  });
};

User.initialize_edit = function () {
  $("#advanced-settings-section,#enhancement-settings-section,#security-settings-section").hide();
  $("#edit-options a:not(#delete-account)").on("click", function (event) {
    const $target = $(event.target);
    $("h2 a").removeClass("active");
    $("#basic-settings-section,#advanced-settings-section,#enhancement-settings-section,#security-settings-section").hide();
    $target.addClass("active");
    $($target.attr("href") + "-section").show();
    event.preventDefault();
  });
};

$(function () {
  if (page("users", "show")) {
    User.initialize_tabs();
    User.initialize_permissions();
  }
  if (page("users", "edit")) {
    User.initialize_edit();
  }
});

export default User;
