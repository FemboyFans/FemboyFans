import LStorage from "./utility/storage";
import Utility from "./utility";
import {page} from "./utility/page";
class Mascots {
  static current = 0;

  static get active() {
    return JSON.parse(Utility.meta("active-mascots") || "{}");
  }

  static show(mascot) {
    $("body").css("background-image", `url(${mascot.background_url})`)
             .css("background-color", mascot.background_color);
    $(".mascotbox").css("background-image", `url(${mascot.background_url})`)
                   .css("background-color", mascot.background_color);

    const artistLink = $("<span>").text("Mascot by ").append($("<a>").text(mascot.artist_name).attr("href", mascot.artist_url));
    $("#mascot_artist").empty().append(artistLink);
  }

  static change() {
    const availableMascotIds = Object.keys(this.active);
    const currentMascotIndex = availableMascotIds.indexOf(this.current + "");

    this.current = availableMascotIds[(currentMascotIndex + 1) % availableMascotIds.length];
    this.show(this.active[Mascots.current]);

    LStorage.Site.Mascot = Mascots.current;
  }

  static init() {
    const changeMascotButton = $("#change-mascot");
    if (Object.keys(this.active).length === 0) {
      console.log("No mascots to display");
      changeMascotButton.remove();
      return;
    }

    changeMascotButton.on("click", () => this.change());
    this.current = LStorage.Site.Mascot;
    if (!this.active[Mascots.current]) {
      const availableMascotIds = Object.keys(this.active);
      const mascotIndex = Math.floor(Math.random() * availableMascotIds.length);
      Mascots.current = availableMascotIds[mascotIndex];
    }
    this.show(this.active[this.current]);
  }
}

export default Mascots;

$(function () {
    if (page("static", "home")) {
      Mascots.init();
    }
});
