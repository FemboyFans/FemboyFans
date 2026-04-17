import Utility from "../utility";

export default class DefaultPosts {
  static _added = [];

  static get ids() {
    return Utility.meta("deferred-posts").split(",");
  }

  static get list() {
    const list = [];
    for (const id of this.ids) {
      const post = Utility.meta(`deferred-posts-${id}`);
      if (!post) continue;
      list.push(JSON.parse(post));
    }

    return [...list, ...this._added];
  }

  static get map() {
    return Object.fromEntries(this.list.map(l => [String(l.id), l]));
  }

  static add(post) {
    this._added.push(post);
  }

  static get(id) {
    return this.map[String(id)];
  }
}
