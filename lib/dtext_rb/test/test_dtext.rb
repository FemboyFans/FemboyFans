# frozen_string_literal: true

require "dtext"
require "cgi"
require "minitest/autorun"
require "nokogiri"

class DTextTest < Minitest::Test
  def parse(*args, **options)
    DText.parse(*args, **options)
  end

  def parse_dtext(...)
    parse(...)&.[](:dtext)
  end

  def parse_inline(dtext)
    parse_dtext(dtext, inline: true)
  end

  def assert_parse_id_link(class_name, url, input, text: input, **options)
    if url[0] == "/"
      assert_parse(%{<p><a class="dtext-link dtext-id-link #{class_name}" href="#{url}">#{text}</a></p>}, input, **options)
      assert_parse(%{<p><a class="dtext-link dtext-id-link #{class_name}" href="http://danbooru.donmai.us#{url}">#{text}</a></p>}, input, base_url: "http://danbooru.donmai.us", **options)
    else
      assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-id-link #{class_name}" href="#{url}">#{text}</a></p>}, input, **options)
      assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-id-link #{class_name}" href="#{url}">#{text}</a></p>}, input, base_url: "http://danbooru.donmai.us", **options)
    end
  end

  def assert_parse(expected, input, **options)
    if expected.nil?
      assert_nil(parse_dtext(input, **options))
    else
      assert_equal(expected, parse_dtext(input, **options), "DText: #{input}")
    end
  end

  def assert_parse_extra(dtext: nil, wiki_pages: nil, post_ids: nil, mentions: nil, input:, **options)
    result = parse(input, **options)
    assert_equal(result[:dtext], dtext, "DText: #{input} (dtext)") unless dtext.nil?
    assert_equal(result[:wiki_pages], wiki_pages, "DText: #{input} (wiki_pages)") unless wiki_pages.nil?
    assert_equal(result[:post_ids], post_ids, "DText: #{input} (post_ids)") unless post_ids.nil?
    assert_equal(result[:mentions], mentions, "DText: #{input} (mentions)") unless mentions.nil?
  end

  def assert_inline_parse(expected, input)
    assert_parse(expected, input, inline: true)
  end

  def assert_mention(expected_username, input, **)
    result = parse(input, **)
    actual_username = Nokogiri::HTML5.fragment(result[:dtext]).css("a.dtext-user-mention-link").text

    assert_equal([expected_username], result[:mentions])
    assert_equal("@" + expected_username, actual_username)
  end

  def assert_qtag(qtag, input, **)
    result = parse(input, qtags: true, **)
    actual_qtag = Nokogiri::HTML5.fragment(result[:dtext]).css("a.dtext-qtag-link").text

    assert_equal(result[:qtags].include?(qtag), true)
    assert_equal("#" + qtag, actual_qtag)
  end

  def test_relative_urls
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="http://danbooru.donmai.us/posts/1234">post #1234</a></p>', "post #1234", base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="http://danbooru.donmai.us/wiki_pages/show_or_new?title=touhou">touhou</a></p>', "[[touhou]]", base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="http://danbooru.donmai.us/wiki_pages/show_or_new?title=touhou">Touhou</a></p>', "[[touhou|Touhou]]", base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="http://danbooru.donmai.us/posts?tags=touhou">touhou</a></p>', "{{touhou}}", base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-forum-topic-id-link" href="http://danbooru.donmai.us/forums/topics/1234?page=4">topic #1234 (page 4)</a></p>', "topic #1234/p4", base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="http://danbooru.donmai.us/posts">home</a></p>', '"home":/posts', base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="http://danbooru.donmai.us#posts">home</a></p>', '"home":#posts', base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="http://danbooru.donmai.us/posts">home</a></p>', '<a href="/posts">home</a>', base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="http://danbooru.donmai.us#posts">home</a></p>', '<a href="#posts">home</a>', base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="evazion" href="http://danbooru.donmai.us/users?name=evazion">@evazion</a></p>', "@evazion", base_url: "http://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="evazion" href="http://danbooru.donmai.us/users?name=evazion">@evazion</a></p>', "<@evazion>", base_url: "http://danbooru.donmai.us")
  end

  def test_args
    assert_parse(nil, nil)
    assert_parse("", "")
    assert_raises(TypeError) { parse_dtext(42) }
  end

  def test_mentions
    assert_mention("user", "@user")
    assert_mention("user", "hi @user")
    assert_mention("user", "@user:")
    assert_mention("user", "@user?")
    assert_mention("user", "/@user")
    assert_mention("user", "(@user)")
    assert_mention("user", '(@user: blah')
    assert_mention("user", '[i]@user [/i]')
    assert_mention("user", '[quote]@user:')
    assert_mention("user", 'Twitter/@user')
    assert_mention("factory", '[b][@factory (Asakura Kotomi)] KotoKoi (Nisekoi)[/b]')

    assert_mention("user", "@user's")
    assert_mention('user', '@user...')
    assert_mention('user', '"@user"')
    assert_mention('user', '"@user":')
    assert_mention('user', '(and "@user");')
    assert_mention("user", "(@user?)")
    assert_mention("user", "(@user!)")
    assert_mention("user", "(@user).")
    assert_mention("user", "(@user),")
    assert_mention("user", "@user- hi")
    assert_mention("user", '[i]@user:[/i]')
    assert_mention("user", '[i]@user[/i]')
    assert_mention("Bunch", '[i]Comic @Bunch[/i]')
    assert_mention("TunaMayo", '@TunaMayo,　乙でした～.')

    assert_mention("21", 'https://www.youtube.com/watch?v=gUxxclCqD8g (@21:50)') # XXX wrong
    assert_mention('1027x768', '12"@1027x768') # XXX wrong
    assert_mention("和茶_Official", "[喜欢]@和茶_Official") # XXX wrong
    assert_mention("amazonses.com", "(from <[redacted]@amazonses.com>)") # XXX wrong
    assert_mention("waniguchi", "(Twitter ID: @waniguchi_)") # XXX wrong
    assert_mention("rifu", "@rifu_ from twitter") # XXX wrong

    assert_parse('<p>this is not @.@ @_@ <a class="dtext-link dtext-user-mention-link" data-user-name="bob" href="/users?name=bob">@bob</a></p>', "this is not @.@ @_@ @bob")
    assert_parse('<p>multiple <a class="dtext-link dtext-user-mention-link" data-user-name="bob" href="/users?name=bob">@bob</a> <a class="dtext-link dtext-user-mention-link" data-user-name="anna" href="/users?name=anna">@anna</a></p>', "multiple @bob @anna")

    assert_mention("_cf", "@_cf")
    assert_mention(".musouka", "@.musouka")
    assert_mention(".dank", "@.dank")
    assert_mention("kia'ra", "@kia'ra")
    assert_mention("T34/38", "@T34/38")
    assert_mention("F/A-18F", "@F/A-18F")
    assert_mention("79248cm/s", "@79248cm/s:")
    assert_mention("games.2019", "@games.2019")
    assert_mention(".k1.38+23", "@.k1.38+23")
    assert_mention('T!ramisu', '@T!ramisu')
    assert_mention("PostIt-Notes", "@PostIt-Notes")
    assert_mention("Fox/Tamamo™", "@Fox/Tamamo™")
    assert_mention("Équi_libriste", "@Équi_libriste")
    assert_mention("111K女", "@111K女")
    assert_mention("🌟💖🌈RainbowStarblast🌈💖🌟", "@🌟💖🌈RainbowStarblast🌈💖🌟")

    assert_mention("初　音　ミ　ク", "@初　音　ミ　ク") # XXX shouldn't work
    assert_mention("http", "@http://example.com") # XXX shouldn't work

    assert_parse('<p>@e?</p>', '@e?') # XXX should work
    assert_parse("<p>@[KN]</p>", "@[KN]") # XXX should work
    assert_parse("<p>@|Leo|</p>", "@|Leo|") # XXX should work
    assert_parse("<p>@-abraxas-</p>", "@-abraxas-") # XXX should work
    assert_parse("<p>@-Yangbojian</p>", "@-Yangbojian") # XXX should work

    assert_mention("deadW", "@deadW@nderer") # XXX wrong
    assert_mention("sweetpe", "@sweetpe@") # XXX wrong
    assert_mention("Nito", "@Nito(ri^n)") # XXX wrong
    assert_mention("Lucas", "@Lucas#Vidal:") # XXX wrong
  end

  def test_nonmentions
    assert_parse('<p>@@</p>', "@@")
    assert_parse('<p>@+</p>', "@+")
    assert_parse('<p>@_</p>', "@_")
    assert_parse('<p>@?</p>', "@?")
    assert_parse('<p>@N</p>', "@N")
    assert_parse('<p>@$$</p>', "@$$")
    assert_parse('<p>@s*</p>', "@s*")
    assert_parse('<p>@%%</p>', "@%%")
    assert_parse('<p>@.@</p>', "@.@")
    assert_parse('<p>@.o</p>', "@.o")
    assert_parse('<p>@_o</p>', "@_o")
    assert_parse('<p>@_X</p>', "@_X")
    assert_parse('<p>@_@</p>', "@_@")
    assert_parse('<p>@¬@</p>', "@¬@")
    assert_parse('<p>@w@</p>', "@w@")
    assert_parse('<p>@m@;</p>', "@m@;")
    assert_parse('<p>@n@</p>', "@n@")
    assert_parse('<p>@A@</p>', "@A@")
    assert_parse('<p>@A@?</p>', "@A@?")
    assert_parse('<p>@3@</p>', "@3@")
    assert_parse('<p>@__X</p>', "@__X")
    assert_parse('<p>@__@</p>', "@__@")
    assert_parse('<p>@_@k</p>', "@_@k")
    assert_parse('<p>@_@&quot;</p>', '@_@"')
    assert_parse('<p>@_@:</p>', "@_@:")
    assert_parse('<p>@_@,.</p>', "@_@,.")
    assert_parse('<p>@_@...</p>', "@_@...")
    assert_parse('<p>@_@!~</p>', "@_@!~")
    assert_parse('<p>@(_   _)</p>', "@(_   _)")
    assert_parse('<p>@_@[/quote]</p>', "@_@[/quote]")
    assert_parse('<p>@///@</p>', "@///@")
    assert_parse('<p>@===&gt;</p>', "@===>")
    assert_parse('<p>@#(&amp;*.</p>', "@#(&*.")
    assert_parse('<p>@*$-pull</p>', "@*$-pull")
    assert_parse('<p>@@</p>', "@@")
    assert_parse('<p>@@,but</p>', "@@,but")
    assert_parse('<p> @: </p>', " @: ")
    assert_parse('<p> @, </p>', " @, ")
    assert_parse('<p>@/\/\ao</p>', '@/\/\ao')
    assert_parse('<p>@.@;;;</p>', "@.@;;;")
    assert_parse("<p>@'d</p>", "@'d")
    assert_parse("<p>@'ing</p>", "@'ing")
    assert_parse('<p>@-like</p>', "@-like")
    assert_parse('<p>@-chan</p>', "@-chan")
    assert_parse('<p>@-mention</p>', "@-mention")
    assert_parse('<p>@-moz-document</p>', "@-moz-document")
    assert_parse('<p>@&quot;I love ProgRock&quot;</p>', '@"I love ProgRock"')
    assert_parse('<p>@@text</p>', "@@text")
    assert_parse('<p>@o@</p>', "@o@")
    assert_parse('<p>@.o&quot;</p>', '@.o"')
    assert_parse("<p>@.o''</p>", "@.o''")
    assert_parse('<p>things(@_0;...</p>', 'things(@_0;...')
    assert_parse('<p>(@﹏@) . . .</p>', '(@﹏@) . . .')

    assert_parse('<p>Q^$@T5#</p>', "Q^$@T5#")
    assert_parse('<p>f#*@ing</p>', "f#*@ing")
    assert_parse('<p>sick f$#@s!</p>', 'sick f$#@s!')
    assert_parse('<p>motherf&amp;#@er!</p>', 'motherf&#@er!')
    assert_parse('<p>mutha&amp;#*@ing</p>', "mutha&#*@ing")
    assert_parse('<p>...@you guys.</p>', "...@you guys.")
    assert_parse('<p>*chuckle*@the cocks tag</p>', "*chuckle*@the cocks tag")
    assert_parse('<p>Poi!@poi?</p>', 'Poi!@poi?')
    assert_parse('<p> @0:43?</p>', ' @0:43?')

    assert_parse('<p>email@address.com</p>', "email@address.com")
    assert_parse('<p>idolm@ster</p>', 'idolm@ster')

    assert_parse('<p>@<strong>Biribiri-chan</strong></p>', '@[b]Biribiri-chan[/b]')
    assert_parse('<p>@<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="https://twitter.com/eshaolang">@eshaolang</a></p>', '@"@eshaolang":[https://twitter.com/eshaolang]')
  end

  def test_disabled_mentions
    assert_parse('<p>@bob</p>', "@bob", disable_mentions: true)
    assert_parse('<p>&lt;@bob&gt;</p>', "<@bob>", disable_mentions: true)

    assert_parse('<p>@bob<em>blah</em></p>', "@bob[i]blah[/i]", disable_mentions: true)
    assert_parse('<p>&lt;@bob<em>blah</em>&gt;</p>', "<@bob[i]blah[/i]>", disable_mentions: true)
    assert_parse('<p>@<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="https://twitter.com/eshaolang">@eshaolang</a></p>', '@"@eshaolang":[https://twitter.com/eshaolang]', disable_mentions: true)
  end

  def test_qtags
    assert_qtag("ych", "#ych")
    assert_qtag("forsale", "#forsale")
    assert_qtag("commissionsopen", "#commissionsopen")
    assert_qtag("furryfandom", "#furryfandom")
    assert_qtag("furry_fandom", "#furry_fandom")
    assert_qtag("gay", "#gay")
    assert_qtag("aot", "#aot")
  end

  def test_sanitize_html_entities
    assert_parse('<p>&lt;3</p>', "<3")
    assert_parse('<p>&lt;</p>', "<")
    assert_parse('<p>&gt;</p>', ">")
    assert_parse('<p>&amp;</p>', "&")
    assert_parse('<p>&quot;</p>', '"')
  end

  def test_html_entities
    assert_inline_parse("&amp;", "&amp;")
    assert_inline_parse("&lt;", "&lt;")
    assert_inline_parse("&gt;", "&gt;")
    assert_inline_parse("&quot;", "&quot;")
    assert_inline_parse("'", "&#39;")
    assert_inline_parse("'", "&apos;")
    assert_inline_parse("[", "&lbrack;")
    assert_inline_parse("*", "&ast;")
    assert_inline_parse(":", "&colon;")
    assert_inline_parse("@", "&commat;")
    assert_inline_parse("`", "&grave;")
    assert_inline_parse("#", "&num;")
    assert_inline_parse(".", "&period;")

    assert_inline_parse("&amp;lt;", "&amp;lt;")
    assert_inline_parse("&lt;b&gt;foo&lt;/b&gt;", "&lt;b&gt;foo&lt;/b&gt;")
    assert_inline_parse("[b]foo[/b]", "&lbrack;b]foo&lbrack;/b]")
    assert_inline_parse("{{foo}}", "&lbrace;&lbrace;foo}}")
    assert_inline_parse("http://google.com", "http&colon;//google.com")
    assert_inline_parse("&quot;title&quot;:/posts", "&quot;title&quot;:/posts")
    assert_inline_parse("@user", "&commat;user")
    assert_inline_parse("post #1", "post &num;1")
    assert_parse("<p>h4. See also</p>", "h4&period; See also")
    assert_parse("<p>* list</p>", "&ast; list")

    assert_inline_parse('<a class="dtext-link" href="/posts">&amp;quot;title&amp;quot;</a>', '"&quot;title&quot;":/posts')
    assert_inline_parse('<a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tiger_%26amp%3B_bunny">tiger_&amp;amp;_bunny</a>', '[[tiger_&amp;_bunny]]')

    assert_inline_parse('&amp;lt;', '[nodtext]&lt;[/nodtext]')
    assert_parse('<pre>&amp;lt;</pre>', '[code]&lt;[/code]')
  end

  def test_wiki_links
    assert_parse("<p>a <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=b\">b</a> c</p>", "a [[b]] c")
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=%E6%9D%B1%E6%96%B9\">東方</a></p>", "[[東方]]")
  end

  def test_wiki_link_spacing
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=tag\">tag</a></p>", "[[ tag ]]")
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=tag\">thetagger</a></p>", "the[[ tag ]]ger")
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=tag\">theTagger</a></p>", "the[[ tag|Tag ]]ger")
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=tag\">theTagger</a></p>", "the[[ tag | Tag ]]ger")
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=tag#see-also\">thetagger</a></p>", "the[[ tag #See Also ]]ger")
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=tag#see-also\">theTagger</a></p>", "the[[ tag #See Also | Tag ]]ger")
  end

  def test_wiki_links_spoiler
    assert_parse("<p>a <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=spoiler\">spoiler</a> c</p>", "a [[spoiler]] c")
  end

  def test_wiki_links_edge
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%7C3">|3</a></p>', '[[|3]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%7Cd">|D</a></p>', '[[|D]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%3A%7C">:|</a></p>', '[[:|]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%7C_%7C">|_|</a></p>', '[[|_|]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%7C%7C_%7C%7C">||_||</a></p>', '[[||_||]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%5C%7C%7C%2F">\||/</a></p>', '[[\||/]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%3C%7C%3E_%3C%7C%3E">&lt;|&gt;_&lt;|&gt;</a></p>', '[[<|>_<|>]]')

    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%7C3">blah</a></p>', '[[|3|blah]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%7Cd">blah</a></p>', '[[|D|blah]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%7C_%7C">blah</a></p>', '[[|_||blah]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%7C%7C_%7C%7C">blah</a></p>', '[[||_|||blah]]')

    #assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%3A%7C">blah</a></p>', '[[:||blah]]') # XXX should work
    #assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%5C%7C%7C%2F">blah</a></p>', '[[\||/|blah]]') # XXX should work
    #assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%3C%7C%3E_%3C%7C%3E">blah</a></p>', '[[<|>_<|>|blah]]') # XXX should work
  end

  def test_wiki_links_nested_b
    assert_parse("<p><strong>[[</strong>tag<strong>]]</strong></p>", "[b][[[/b]tag[b]]][/b]")
  end

  def test_wiki_links_suffixes
    assert_parse('<p>I like <a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=cat">cats</a>.</p>', "I like [[cat]]s.")
    assert_parse('<p>a <a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=cat">cat</a>\'s paw</p>', "a [[cat]]'s paw")
    assert_parse('<p>the <a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=60s">1960s</a>.</p>', "the 19[[60s]].")
    assert_parse('<p>a <a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=c">bcd</a> e</p>', "a b[[c]]d e")

    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=b">acd</a></p>', "a[[b|c]]d")
  end

  def test_wiki_links_pipe_trick
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tagme">tagme</a></p>', "[[tagme|]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tagme">TAGME</a></p>', "[[TAGME|]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tagme">tagme</a></p>', "[[tagme| ]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tagme">tagme</a></p>', "[[tagme |]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tagme">tagme</a></p>', "[[tagme | ]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=foo_%28bar%29">foo</a></p>', "[[foo (bar)|]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=foo_%28bar%29">foo</a></p>', "[[foo (bar) | ]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=foo_%28bar%29">abcfoo123</a></p>', "abc[[foo (bar)|]]123")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=foo_%28bar%29">abcfoo123</a></p>', "abc[[foo (bar) | ]]123")

    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=kaga_%28kantai_collection%29">kaga</a></p>', "[[kaga_(kantai_collection)|]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=kaga_%28kantai_collection%29">Kaga</a></p>', "[[Kaga (Kantai Collection)|]]")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=kaga_%28kantai_collection%29_%28cosplay%29">kaga (kantai collection)</a></p>', "[[kaga (kantai collection) (cosplay)|]]")

    assert_parse('<p>[[long hair|<br>long]]</p>', "[[long hair|\nlong]]")
    assert_parse('<p>[[|long hair]]</p>', "[[|long hair]]")
  end

  def test_wiki_links_anchor
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=touhou#see-also">touhou</a></p>', '[[touhou#See also]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=touhou#see-also">touhou</a></p>', '[[touhou#See-Also]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=touhou#see-also">touhou</a></p>', '[[touhou#See_Also]]')

    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=cd#ef">abghij</a></p>', 'ab[[cd#Ef|gh]]ij')

    assert_parse('<p>[[touhou#See Also:]]</p>', '[[touhou#See Also:]]')
    assert_parse('<p>[[Htol#Niq: Hotaru no Nikki#See also]]</p>', '[[Htol#Niq: Hotaru no Nikki#See also]]')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tokyo_mirage_sessions#fe">Tokyo Mirage Sessions</a></p>', '[[Tokyo Mirage Sessions #FE]]') # XXX wrong
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=http%3A%2F%2Fen.wikipedia.org%2Fwiki%2Fgolden_age_of_detective_fiction#description-of-the-genre">Knox Decalogue</a></p>', '[[http://en.wikipedia.org/wiki/Golden_Age_of_Detective_Fiction#Description_of_the_genre| Knox Decalogue]]') # XXX wrong
  end

  def test_spoilers
    assert_parse("<p>this is <span class=\"spoiler\">an inline spoiler</span>.</p>", "this is [spoiler]an inline spoiler[/spoiler].")
    assert_parse("<p>this is <span class=\"spoiler\">an inline spoiler</span>.</p>", "this is [SPOILERS]an inline spoiler[/SPOILERS].")
    assert_parse("<p>this is</p><div class=\"spoiler\"><p>a block spoiler</p></div><p>.</p>", "this is\n\n[spoiler]\na block spoiler\n[/spoiler].")
    assert_parse("<p>this is</p><div class=\"spoiler\"><p>a block spoiler</p></div><p>.</p>", "this is\n\n[SPOILERS]\na block spoiler\n[/SPOILERS].")
    assert_parse("<div class=\"spoiler\"><p>this is a spoiler with no closing tag</p><p>new text</p></div>", "[spoiler]this is a spoiler with no closing tag\n\nnew text")
    assert_parse("<div class=\"spoiler\"><p>this is a spoiler with no closing tag<br>new text</p></div>", "[spoiler]this is a spoiler with no closing tag\nnew text")
    assert_parse("<div class=\"spoiler\"><p>this is a block spoiler with no closing tag</p></div>", "[spoiler]\nthis is a block spoiler with no closing tag")
    assert_parse("<div class=\"spoiler\"><p>this is <span class=\"spoiler\">a nested</span> spoiler</p></div>", "[spoiler]this is [spoiler]a nested[/spoiler] spoiler[/spoiler]")

    assert_parse('<div class="spoiler"><h4>Blah</h4></div>', "[spoiler]\nh4. Blah\n[/spoiler]")
    assert_parse('<div class="spoiler"><h4>Blah</h4></div>', "[spoiler]\n\nh4. Blah\n[/spoiler]")
    assert_parse('<p>First sentence</p><p>[/spoiler] Second sentence.</p>', "First sentence\n\n[/spoiler] Second sentence.")

    assert_parse('<p>inline <em>foo</em></p><div class="spoiler"><p>blah blah</p></div>', "inline [i]foo\n\n[spoiler]blah blah[/spoiler]")
    assert_parse('<p>inline <span class="spoiler"> foo</span></p><div class="spoiler"><p>blah blah</p></div>', "inline [spoiler] foo\n\n[spoiler]blah blah[/spoiler]")

    assert_parse('<ul><li>one</li></ul><div class="spoiler"><ul><li>two</li></ul></div><ul><li>three</li></ul>', "* one\n[spoiler]\n* two\n[/spoiler]\n* three")

    assert_parse('<p>one</p><div class="spoiler"><p>two</p></div><p>three</p>', "one\n[spoiler]\ntwo\n[/spoiler]\nthree")
    assert_parse('<p>one</p><div class="spoiler"><p>two</p></div><p>three</p>', "one\n[spoiler]\ntwo\n[/spoiler]three")
    assert_parse('<p>one<br><span class="spoiler">two</span><br>three</p>', "one\n[spoiler]two[/spoiler]\nthree")
    assert_parse('<p>one<br><span class="spoiler">two</span></p>', "one\n[spoiler]two")
    assert_parse('<p>one</p><div class="spoiler"></div>', "one\n[spoiler]")
    assert_parse('<blockquote><p>user said:</p><div class="spoiler"><p>aeris dies</p></div></blockquote>', "[quote]user said:\n[spoiler]\naeris dies[/spoiler]\n[/quote]")

    assert_parse('<div class="spoiler"><p>foo</p></div>', "[spoiler]\n\nfoo\n\n[/spoiler]")

    # assert_parse('<p>inline <span class="spoiler">foo</span></p><p>[/spoiler]</p>', "inline [spoiler]foo\n\n[/spoiler]")
    assert_parse('<p>inline <span class="spoiler">foo</span></p>', "inline [spoiler]foo\n\n[/spoiler]") # XXX wrong

    # assert_parse('<div class="spoiler"><p>foo</p></div>', "[spoiler]\nfoo\n [/spoiler]") # XXX
    assert_parse('<div class="spoiler"><p>foo</p></div>', "[spoiler]\nfoo\n\n [/spoiler]")
    assert_parse('<div class="spoiler"><ul><li>foo</li></ul></div>', "[spoiler]\n* foo\n [/spoiler]")
  end

  def test_paragraphs
    assert_parse("<p>abc</p>", "abc")
    assert_parse("<p>a<br>b<br>c</p>", "a\nb\nc")
    assert_parse("<p>a</p><p>b</p>", "a\n\nb")
    assert_parse("<p>a</p><p>b</p>", "a\r\n\r\nb")
    assert_parse("<p>a</p><p>b</p>", "a \n\nb")
    assert_parse("<p>a</p><p>b</p>", "a\n \nb")
    assert_parse("<p>a</p><p>b</p>", "a \n \nb")
    assert_parse("<p>a</p><p> b</p>", "a\n\n b") # XXX strip space?

    assert_parse("<p>a</p>", "a\n ")
    assert_parse("<p>a</p>", "a \n")
    assert_parse("<p>a</p>", "a \n ")

    assert_parse("<p>a</p>", "a\n\n ")
    assert_parse("<p>a</p>", "a\n \n")
    assert_parse("<p>a</p>", "a \n\n")
    assert_parse("<p>a</p>", "a \n \n ")

    assert_parse("a<br>b<br>c", "a\nb\nc", inline: true)
    assert_parse("", "", inline: true)
    assert_parse("a", "\n\na", inline: true)
    assert_parse("a ", "a\n\n", inline: true) # XXX should strip space
    assert_parse("a b", "a\n\nb", inline: true)
    assert_parse("a b", "a\r\n\r\nb", inline: true)
    assert_parse("a b", "a \n\nb", inline: true)
    assert_parse("a b", "a\n \nb", inline: true)
    assert_parse("a b", "a \n \nb", inline: true)
    assert_parse("a  b", "a\n\n b", inline: true) # XXX strip space?
  end

  def test_headers
    assert_parse("<h1>header</h1>", "h1. header")
    assert_parse("<ul><li>a</li></ul><h1>header</h1><ul><li>list</li></ul>", "* a\n\nh1. header\n* list")
    assert_parse("<p>blah h1. blah</p>", "blah h1. blah")

    assert_parse('<h1 id="dtext-blah">header</h1>', "h1#blah. header")
    assert_parse('<h1 id="dtext-see-also">header</h1>', "h1#See_Also. header")
    assert_parse('<h1 id="dtext-see-also-42">header</h1>', "h1#See_Also&42. header")
    assert_parse('<h1 id="dtext--see-also-42-">header</h1>', "h1#-See_Also&42-. header")
    assert_parse('<h1 id="dtext-see-also">header</h1>', "h1#see-also. header")
    assert_parse('<p>h1#See Also. header</p>', "h1#See Also. header")
    assert_parse('<p>h1#see-&quot;also. header</p>', 'h1#see-"also. header')

    assert_parse('<p>text</p><h1>header</h1>', "text\nh1. header")
    assert_parse('<p>text</p><h1 id="dtext-blah">header</h1>', "text\nh1#blah. header")
    assert_parse('<p><em>text</em></p><h1>header</h1>', "[i]text\nh1. header")
    assert_parse('<div class="spoiler"><p>text</p><h1>header</h1></div>', "[spoiler]text\nh1. header")
    assert_parse('<h1>header</h1><p>text</p>', "h1. header\ntext")
    assert_parse('<ul><li>one</li></ul><h1>header</h1>', "* one\nh1. header")
    assert_parse('<ul><li>one</li></ul><h1>header</h1><ul><li>two</li></ul>', "* one\nh1. header\n* two")
    assert_parse('<h1>header</h1><h2>header</h2>', "h1. header\nh2. header")

    assert_parse('<h1><em>header</em></h1><p>blah</p>', "h1. [i]header\nblah")
    assert_parse('<h1><span class="spoiler">header</span></h1><p>blah</p>', "h1. [spoiler]header\nblah")
    assert_parse('<h1><span class="dtext-note">header</span></h1><p>blah</p>', "h1. [note]header\nblah")
    assert_parse('<h1><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a></h1><p>blah</p>', %{h1. http://example.com\nblah})
    assert_parse('<h1><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></h1><p>blah</p>', %{h1. "example":http://example.com\nblah})

    assert_parse('<blockquote><blockquote><h1>header</h1></blockquote></blockquote>', %{[quote]\n\n[quote]\n\nh1. header\n[/quote]\n\n[/quote]})

    assert_parse('<blockquote><h1>header</h1></blockquote><p>one<br>two</p>', %{[quote]\nh1. header\n[/quote]\none\ntwo})

    assert_parse('<p>foo <strong>bar</strong></p><h4>See also</h4>', "foo [b]bar\nh4. See also")
  end

  def test_thumbnails
    assert_parse_extra(post_ids: [1], dtext: "<p><a class=\"dtext-link dtext-id-link dtext-post-id-link thumb-placeholder-link\" data-id=\"1\" href=\"/posts/1\">post #1</a></p>", input: "thumb #1")
    assert_parse_extra(post_ids: [1, 2], dtext: "<p><a class=\"dtext-link dtext-id-link dtext-post-id-link thumb-placeholder-link\" data-id=\"1\" href=\"/posts/1\">post #1</a> <a class=\"dtext-link dtext-id-link dtext-post-id-link thumb-placeholder-link\" data-id=\"2\" href=\"/posts/2\">post #2</a></p>", input: "thumb #1 thumb #2")
    assert_parse_extra(post_ids: [1], dtext: "<p><a class=\"dtext-link dtext-id-link dtext-post-id-link thumb-placeholder-link\" data-id=\"1\" href=\"/posts/1\">post #1</a> <a class=\"dtext-link dtext-id-link dtext-post-id-link\" href=\"/posts/2\">post #2</a></p>", input: "thumb #1 thumb #2", max_thumbs: 1)
    assert_parse_extra(post_ids: [], dtext: "<p><a class=\"dtext-link dtext-id-link dtext-post-id-link\" href=\"/posts/1\">post #1</a> <a class=\"dtext-link dtext-id-link dtext-post-id-link\" href=\"/posts/2\">post #2</a></p>", input: "thumb #1 thumb #2", max_thumbs: 0)
  end

  def test_color
    assert_parse("<p><span class=\"dtext-color\" style=\"color: #FFA500\">test</span></p>", "[color=#FFA500]test[/color]", allow_color: true)
    assert_parse("<p><span class=\"dtext-color\" style=\"color: orangered\">test</span></p>", "[color=orangered]test[/color]", allow_color: true)
    assert_parse("<p>test</p>", "[color=orangered]test[/color]", allow_color: false)
    typed = %w[general gen artist art contributor cont copyright copy co character char ch oc species spec invalid inv meta lore lor gender safe questionable explicit]
    typed.each do |category|
      assert_parse("<p><span class=\"dtext-color-#{category}\">test</span></p>", "[color=#{category}]test[/color]", allow_color: true)
    end
  end

  def test_inline_elements
    assert_inline_parse("<strong>foo</strong>", "[b]foo[/b]")
    assert_inline_parse("<strong>foo</strong>", "<b>foo</b>")
    assert_inline_parse("<strong>foo</strong>", "<strong>foo</strong>")

    assert_inline_parse("<em>foo</em>", "[i]foo[/i]")
    assert_inline_parse("<em>foo</em>", "<i>foo</i>")
    assert_inline_parse("<em>foo</em>", "<em>foo</em>")

    assert_inline_parse("<s>foo</s>", "[s]foo[/s]")
    assert_inline_parse("<s>foo</s>", "<s>foo</s>")

    assert_inline_parse("<u>foo</u>", "[u]foo[/u]")
    assert_inline_parse("<u>foo</u>", "<u>foo</u>")

    assert_inline_parse("<sup>foo</sup>", "[sup]foo[/sup]")
    assert_inline_parse("<sup>foo</sup>", "<sup>foo</sup>")

    assert_inline_parse("<sub>foo</sub>", "[sub]foo[/sub]")
    assert_inline_parse("<sub>foo</sub>", "<sub>foo</sub>")

    assert_inline_parse("blah", "[section]blah[/section]")
    assert_inline_parse("blah", "[section=title]blah[/section]")
  end

  def test_inline_note
    assert_parse('<p>foo <span class="dtext-note">bar</span> baz</p>', "foo [note]bar[/note] baz")
    assert_parse('<p>foo <span class="dtext-note">bar</span> baz</p>', "foo <note>bar</note> baz")

    assert_parse('<p>foo bar[/note] baz</p>', "foo bar[/note] baz")
    assert_parse('<p>foo bar&lt;/note&gt; baz</p>', "foo bar</note> baz")
    assert_parse('<ul><li>foo [/note] bar</li></ul>', "* foo [/note] bar")
    assert_parse('<h4>foo [/note] bar</h4>', "h4. foo [/note] bar")
    assert_parse('<blockquote><p>foo [/note] bar</p></blockquote>', "[quote]\nfoo [/note] bar\n[/quote]")
  end

  def test_anchors
    assert_parse('<p><a id="test"></a></p>', "[#test]")
    assert_parse_extra(wiki_pages: [], dtext: '<p><a class="dtext-link dtext-internal-anchor-link" href="#test">test</a></p>', input: "[[#test]]")
  end

  def test_block_note
    assert_parse('<p class="dtext-note">bar</p>', "[note]bar[/note]")
    assert_parse('<p class="dtext-note">bar</p>', "<note>bar</note>")

    assert_parse('<p>foo <strong>bar</strong></p><p class="dtext-note">bar</p>', "foo [b]bar\n\n[note]bar[/note]")
    assert_parse('<p>foo <strong>bar<br><span class="dtext-note"><br>bar</span></strong></p>', "foo [b]bar\n[note]\nbar\n[/note]") # XXX should be treated as a block tag?
  end

  def test_quote_blocks
    assert_parse('<blockquote><p>test</p></blockquote>', "[quote]\ntest\n[/quote]")
    assert_parse('<blockquote><p>test</p></blockquote>', "<quote>\ntest\n</quote>")

    assert_parse('<blockquote><p>test</p></blockquote>', "[quote]\ntest\n[/quote] ")
    assert_parse('<blockquote><p>test</p></blockquote><p>blah</p>', "[quote]\ntest\n[/quote] blah")
    assert_parse('<blockquote><p>test</p></blockquote><p>blah</p>', "[quote]\ntest\n[/quote] \nblah")
    assert_parse('<blockquote><p>test</p></blockquote><p>blah</p>', "[quote]\ntest\n[/quote]\nblah")
    assert_parse('<blockquote><p>test</p></blockquote><p> blah</p>', "[quote]\ntest\n[/quote]\n blah") # XXX should ignore space

    assert_parse('<p>test<br>[/quote] blah</p>', "test\n[/quote] blah")
    assert_parse('<p>test<br>[/quote]</p><ul><li>blah</li></ul>', "test\n[/quote]\n* blah")

    assert_parse('<blockquote><p>test</p></blockquote><h4>See also</h4>', "[quote]\ntest\n[/quote]\nh4. See also")
    assert_parse('<blockquote><p>test</p></blockquote><div class="spoiler"><p>blah</p></div>', "[quote]\ntest\n[/quote]\n[spoiler]blah[/spoiler]")

    assert_parse("<p>inline </p><blockquote><p>blah blah</p></blockquote>", "inline [quote]blah blah[/quote]")
    assert_parse("<p>inline <em>foo </em></p><blockquote><p>blah blah</p></blockquote>", "inline [i]foo [quote]blah blah[/quote]")
    assert_parse('<p>inline <span class="spoiler">foo </span></p><blockquote><p>blah blah</p></blockquote>', "inline [spoiler]foo [quote]blah blah[/quote]")

    assert_parse("<p>inline <em>foo</em></p><blockquote><p>blah blah</p></blockquote>", "inline [i]foo\n\n[quote]blah blah[/quote]")
    assert_parse('<p>inline <span class="spoiler">foo </span></p><blockquote><p>blah blah</p></blockquote>', "inline [spoiler]\n\nfoo [quote]blah blah[/quote]")

    assert_parse("<p>blah</p><blockquote><p>blah</p></blockquote>", "blah\n[quote]\nblah\n[/quote]")
    assert_parse("<p><strong>unclosed</strong></p><blockquote><p>blah</p></blockquote>", "[b]unclosed\n[quote]\nblah\n[/quote]")
    assert_parse('<p>blah<br><span class="dtext-note"></span></p><blockquote><p>blah</p></blockquote><p>[/note]</p>', "blah\n[note]\n[quote]\nblah[/quote]\n[/note]") # XXX should strip <br> before [note]
    assert_parse('<p><br></p><blockquote><p>blah</p></blockquote>', "[br]\n[quote]\nblah\n[/quote]")

    assert_parse('<blockquote><div class="spoiler"><p>blah</p></div></blockquote>', "[quote][spoiler]blah[/spoiler] [/quote]")
    assert_parse('<blockquote><p>blah said:</p><p>blah</p></blockquote>', "[quote]\nblah said:\n\nblah\n\n [/quote]")
    assert_parse('<blockquote><p>blah</p></blockquote>', "[quote]\nblah\n [/quote]")
    assert_parse('<blockquote><p>blah</p></blockquote>', "[quote]\nblah\n\n [/quote]")
    assert_parse('<blockquote><ul><li>blah</li></ul></blockquote>', "[quote]\n* blah\n [/quote]")

    assert_parse('<p>foo</p><blockquote><p>bar</p></blockquote>', "foo\n [quote]bar[/quote]")
    assert_parse('<p>foo</p><p> </p><blockquote><p>bar</p></blockquote>', "foo\n\n [quote]bar[/quote]") # XXX wrong
  end

  def test_quote_blocks_with_list
    assert_parse("<blockquote><ul><li>hello</li><li>there</li></ul></blockquote><p>abc</p>", "[quote]\n* hello\n* there\n[/quote]\nabc")
    assert_parse("<blockquote><ul><li>hello</li><li>there</li></ul></blockquote><p>abc</p>", "[quote]\n* hello\n* there\n\n[/quote]\nabc")
  end

  def test_quote_with_unclosed_tags
    assert_parse('<blockquote><p><strong>foo</strong></p></blockquote>', "[quote][b]foo[/quote]")
    assert_parse('<blockquote><blockquote><p>foo</p></blockquote></blockquote>', "[quote][quote]foo[/quote]")
    assert_parse('<blockquote><div class="spoiler"><p>foo</p></div></blockquote>', "[quote][spoiler]foo[/quote]")
    assert_parse('<blockquote><pre>foo[/quote]</pre></blockquote>', "[quote][code]foo[/quote]")
    assert_parse('<blockquote><details><summary></summary><div><p>foo</p></div></details></blockquote>', "[quote][section]foo[/quote]")
    assert_parse('<blockquote><p>foo[/quote]</p></blockquote>', "[quote][nodtext]foo[/quote]")
    assert_parse('<blockquote><table class="striped"><td>foo</td></table></blockquote>', "[quote][table][td]foo[/quote]")
    assert_parse('<blockquote><ul><li>foo</li></ul></blockquote>', "[quote]* foo[/quote]")
    assert_parse('<blockquote><h1>foo</h1></blockquote>', "[quote]h1. foo[/quote]")
  end

  def test_quote_blocks_nested
    assert_parse("<blockquote><p>a</p><blockquote><p>b</p></blockquote><p>c</p></blockquote>", "[quote]\na\n[quote]\nb\n[/quote]\nc\n[/quote]")
  end

  def test_quote_blocks_nested_spoiler
    assert_parse("<blockquote><p>a<br><span class=\"spoiler\">blah</span><br>c</p></blockquote>", "[quote]\na\n[spoiler]blah[/spoiler]\nc[/quote]")
    assert_parse("<blockquote><p>a</p><div class=\"spoiler\"><p>blah</p></div><p>c</p></blockquote>", "[quote]\na\n\n[spoiler]blah[/spoiler]\n\nc[/quote]")

    assert_parse('<details><summary></summary><div><div class="spoiler"><ul><li>blah</li></ul></div></div></details>', "[section]\n[spoiler]\n* blah\n[/spoiler]\n[/section]")
  end

  def test_quote_blocks_nested_section
    assert_parse("<blockquote><p>a</p><details><summary></summary><div><p>b</p></div></details><p>c</p></blockquote>", "[quote]\na\n[section]\nb\n[/section]\nc\n[/quote]")
  end

  def test_block_code
    assert_parse("<pre>for (i=0; i&lt;5; ++i) {\n  printf(1);\n}\n\nexit(1);</pre>", "[code]for (i=0; i<5; ++i) {\n  printf(1);\n}\n\nexit(1);")
    assert_parse("<pre>[b]lol[/b]</pre>", "[code][b]lol[/b][/code]")
    assert_parse("<pre>[code]</pre>", "[code][code][/code]")
    assert_parse("<pre>post #123</pre>", "[code]post #123[/code]")
    assert_parse("<pre>x</pre>", "[code]x")

    assert_parse(%{<pre class="language-ruby">x</pre>}, "[code=ruby]\nx\n[/code]")
    assert_parse(%{<pre class="language-ruby">x</pre>}, "[code = ruby]\nx\n[/code]")
    assert_parse("<p>[code=ruby'&gt;]<br>x<br>[/code]</p>", "[code=ruby'>]\nx\n[/code]")
    assert_parse(%{<pre class="language-ruby">code</pre><pre>code</pre>}, "[code=ruby]\ncode\n[/code]\n\n[code]\ncode\n[/code]")

    assert_parse("<pre> bar </pre>", "[code] bar [/code]")
    assert_parse("<pre>bar</pre>", "[code]\nbar\n[/code]")
    assert_parse("<pre>bar </pre>", "[code] \nbar \n[/code]")
    assert_parse("<pre> ▲\n▲ ▲</pre>", "[code]\n ▲\n▲ ▲\n[/code]")

    assert_parse("<p>inline</p><pre>[/i]</pre>", "inline\n\n[code]\n[/i]\n[/code]")
    assert_parse('<p>inline</p><pre>[/i]</pre>', "inline\n\n[code][/i][/code]")
    assert_parse("<p><em>inline</em></p><pre>[/i]</pre>", "[i]inline\n\n[code]\n[/i]\n[/code]")
    assert_parse('<p><em>inline</em></p><pre>[/i]</pre>', "[i]inline\n\n[code][/i][/code]")

    assert_parse('<p>inline</p><pre>[/i]</pre>', "inline\n[code]\n[/i]\n[/code]")
    assert_parse('<p>inline</p><pre>[/i]</pre>', "inline\n[code][/i][/code]")
    assert_parse('<p><em>inline</em></p><pre>[/i]</pre>', "[i]inline\n[code]\n[/i]\n[/code]")
    assert_parse('<p><em>inline</em></p><pre>[/i]</pre>', "[i]inline\n[code][/i][/code]")
  end

  def test_inline_code
    assert_parse("<p>foo <code>[b]lol[/b]</code>.</p>", "foo [code][b]lol[/b][/code].")
    assert_parse("<p>foo <code>[code]</code>.</p>", "foo [code][code][/code].")
    assert_parse("<p>foo <em><code>post #123</code></em>.</p>", "foo [i][code]post #123[/code][/i].")
    assert_parse("<p>foo <code>x</code></p>", "foo [code]x")

    assert_parse('<p>inline <code class="language-ruby">x</code></p>', "inline [code=ruby]x[/code]")
    assert_parse('<p>inline <code class="language-ruby">x</code></p>', "inline [code = ruby]x[/code]")
    assert_parse("<p>inline [code=ruby'&gt;]x[/code]</p>", "inline [code=ruby'>]x[/code]")
    assert_parse('<p>inline <code class="language-ruby">code</code></p><pre>code</pre>', "inline [code=ruby]code[/code]\n[code]code[/code]")

    assert_parse("<p>foo <code> bar </code></p>", "foo [code] bar [/code]")
    assert_parse("<p>foo <code>bar</code></p>", "foo [code]\nbar\n[/code]")
    assert_parse("<p>foo <code>bar </code></p>", "foo [code] \nbar \n[/code]")
    assert_parse("<p>foo <span class=\"inline-code\">bar</span></p>", "foo `bar`")
  end

  def test_urls
    assert_parse('<p>a <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a> b</p>', 'a http://test.com b')
    assert_parse('<p>a <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="Http://test.com">Http://test.com</a> b</p>', 'a Http://test.com b')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a><br>b</p>', "http://test.com\nb")
    assert_parse('<p>a <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>. b</p>', 'a http://test.com. b')
    assert_parse('<p>a (<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>) b</p>', 'a (http://test.com) b')
    assert_parse('<p>a [<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>] b</p>', 'a [http://test.com] b')
    assert_parse('<p>a {<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>} b</p>', 'a {http://test.com} b')
    assert_parse('<p>a(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>) b</p>', 'a(http://test.com) b')
    assert_parse('<p>(at <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com/1234?page=42">http://test.com/1234?page=42</a>). blah</p>', '(at http://test.com/1234?page=42). blah')
    assert_parse('<p>a <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com/~bob/image.jpg">http://test.com/~bob/image.jpg</a> b</p>', 'a http://test.com/~bob/image.jpg b')
    assert_parse('<p>a <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com/home.html#toc">http://test.com/home.html#toc</a> b</p>', 'a http://test.com/home.html#toc b')

    assert_parse('<p>a_<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a_http://test.com')
    assert_parse('<p>a-<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a-http://test.com')
    assert_parse('<p>a*<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a*http://test.com')
    assert_parse('<p>a.<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a.http://test.com')
    assert_parse('<p>a,<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a,http://test.com')
    assert_parse('<p>a/<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a/http://test.com')
    assert_parse('<p>a&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a"http://test.com')
    assert_parse('<p>a\'<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', "a'http://test.com")
    assert_parse('<p>a;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a;http://test.com')

    assert_parse(%{<p>a\u00A0<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>}, "a\u00A0http://test.com") # no-break space
    assert_parse(%{<p>a\u200B<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>}, "a\u200Bhttp://test.com") # zero-width space
    assert_parse(%{<p>a\u2008<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>}, "a\u2008http://test.com") # left-to-right mark
    assert_parse('<p>a　<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a　http://test.com')
    assert_parse('<p>a：<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a：http://test.com')
    assert_parse('<p>a。<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a。http://test.com')
    assert_parse('<p>a→<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', 'a→http://test.com')
    assert_parse('<p>【<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>】</p>', '【http://test.com】')
    assert_parse('<p>「<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>」</p>', '「http://test.com」')
    assert_parse('<p>（<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>）</p>', '（http://test.com）')

    assert_parse('<p>hhttp://example.com</p>', 'hhttp://example.com')
    assert_parse('<p>blahhttp://example.com</p>', 'blahhttp://example.com')
  end

  def test_internal_links
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us">https://danbooru.donmai.us</a></p>', 'https://danbooru.donmai.us', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us">https://danbooru.donmai.us</a></p>', '"https://danbooru.donmai.us":https://danbooru.donmai.us', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/login">https://danbooru.donmai.us</a></p>', '"https://danbooru.donmai.us":https://danbooru.donmai.us/login', domain: "danbooru.donmai.us")

    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/">https://danbooru.donmai.us/</a></p>', 'https://danbooru.donmai.us/', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/?blah">https://danbooru.donmai.us/?blah</a></p>', 'https://danbooru.donmai.us/?blah', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/#foo">https://danbooru.donmai.us/#foo</a></p>', 'https://danbooru.donmai.us/#foo', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us?">https://danbooru.donmai.us?</a></p>', '<https://danbooru.donmai.us?>', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us#">https://danbooru.donmai.us#</a></p>', '<https://danbooru.donmai.us#>', domain: "danbooru.donmai.us")

    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://danbooru.donmai.us">https://danbooru.donmai.us</a></p>', 'https://danbooru.donmai.us', domain: "testbooru.donmai.us")

    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us">https://danbooru.donmai.us</a></p>', 'https://danbooru.donmai.us', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/login">https://danbooru.donmai.us/login</a></p>', 'https://danbooru.donmai.us/login', domain: "danbooru.donmai.us")
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://danbooru.donmai.us/login">https://danbooru.donmai.us/login</a></p>', 'https://danbooru.donmai.us/login', domain: "testbooru.donmai.us")
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://danbooru.donmai.us/login">https://danbooru.donmai.us/login</a></p>', 'https://danbooru.donmai.us/login', domain: "")

    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us">https://danbooru.donmai.us</a></p>', '<https://danbooru.donmai.us>', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/login">https://danbooru.donmai.us/login</a></p>', '<https://danbooru.donmai.us/login>', domain: "danbooru.donmai.us")
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://danbooru.donmai.us/login">https://danbooru.donmai.us/login</a></p>', '<https://danbooru.donmai.us/login>', domain: "testbooru.donmai.us")

    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us">home</a></p>', '"home":https://danbooru.donmai.us', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/login">login</a></p>', '"login":https://danbooru.donmai.us/login', domain: "danbooru.donmai.us")
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="https://danbooru.donmai.us/login">login</a></p>', '"login":https://danbooru.donmai.us/login', domain: "testbooru.donmai.us")

    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us">home</a></p>', '"home":[https://danbooru.donmai.us]', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/login">login</a></p>', '"login":[https://danbooru.donmai.us/login]', domain: "danbooru.donmai.us")
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="https://danbooru.donmai.us/login">login</a></p>', '"login":[https://danbooru.donmai.us/login]', domain: "testbooru.donmai.us")

    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us">home</a></p>', '[https://danbooru.donmai.us](home)', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/login">login</a></p>', '[https://danbooru.donmai.us/login](login)', domain: "danbooru.donmai.us")
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="https://danbooru.donmai.us/login">login</a></p>', '[https://danbooru.donmai.us/login](login)', domain: "testbooru.donmai.us")

    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/posts?tags=simple@house">https://danbooru.donmai.us/posts?tags=simple@house</a></p>', 'https://danbooru.donmai.us/posts?tags=simple@house', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/posts?tags=%s">https://danbooru.donmai.us/posts?tags=%s</a></p>', 'https://danbooru.donmai.us/posts?tags=%s', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/posts?tags=pok%E9mon">https://danbooru.donmai.us/posts?tags=pok%E9mon</a></p>', 'https://danbooru.donmai.us/posts?tags=pok%E9mon', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/posts?tags=foo%00bar">https://danbooru.donmai.us/posts?tags=foo%00bar</a></p>', 'https://danbooru.donmai.us/posts?tags=foo%00bar', domain: "danbooru.donmai.us")

    assert_parse('<p><a class="dtext-link" href="http://danbooru.donmai.us/post/show/810829/arms_behind_back-ayanami_rei">http://danbooru.donmai.us/post/show/810829/arms_behind_back-ayanami_rei</a></p>', 'http://danbooru.donmai.us/post/show/810829/arms_behind_back-ayanami_rei', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="http://danbooru.donmai.us/post/show/#">http://danbooru.donmai.us/post/show/#</a>###</p>', 'http://danbooru.donmai.us/post/show/####', domain: "danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link" href="http://danbooru.donmai.us/posts/#">http://danbooru.donmai.us/posts/#</a>###</p>', 'http://danbooru.donmai.us/posts/####', domain: "danbooru.donmai.us")
  end

  def test_internal_link_to_shortlink_conversion
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://testbooru.donmai.us/posts/1234">https://testbooru.donmai.us/posts/1234</a></p>', "https://testbooru.donmai.us/posts/1234", domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])

    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', 'https://danbooru.donmai.us/posts/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', '<https://danbooru.donmai.us/posts/1234>', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', '"https://danbooru.donmai.us/posts/1234":https://danbooru.donmai.us/posts/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', '"https://danbooru.donmai.us/posts/1234":[https://danbooru.donmai.us/posts/1234]', internal_domains: %w[danbooru.donmai.us])

    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', 'https://danbooru.donmai.us/posts/1234', internal_domains: %w[danbooru.donmai.us betabooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', 'https://betabooru.donmai.us/posts/1234', internal_domains: %w[danbooru.donmai.us betabooru.donmai.us])

    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', 'https://danbooru.donmai.us/posts/1234?q=touhou', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', 'https://danbooru.donmai.us:443/posts/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/posts/1234#comment-5678">https://danbooru.donmai.us/posts/1234#comment-5678</a></p>', 'https://danbooru.donmai.us/posts/1234#comment-5678', domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])

    assert_parse('<p><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1234">post #1234</a></p>', 'https://danbooru.donmai.us/posts/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-pool-id-link" href="/pools/1234">pool #1234</a></p>', 'https://danbooru.donmai.us/pools/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-comment-id-link" href="/comments/1234">comment #1234</a></p>', 'https://danbooru.donmai.us/comments/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-forum-post-id-link" href="/forums/posts/1234">forum #1234</a></p>', 'https://danbooru.donmai.us/forums/posts/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-forum-topic-id-link" href="/forums/topics/1234">topic #1234</a></p>', 'https://danbooru.donmai.us/forums/topics/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-forum-category-id-link" href="/forums/categories/1234">category #1234</a></p>', 'https://danbooru.donmai.us/forums/categories/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-user-id-link" href="/users/1234">user #1234</a></p>', 'https://danbooru.donmai.us/users/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-artist-id-link" href="/artists/1234">artist #1234</a></p>', 'https://danbooru.donmai.us/artists/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-note-id-link" href="/notes/1234">note #1234</a></p>', 'https://danbooru.donmai.us/notes/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-set-id-link" href="/post_sets/1234">set #1234</a></p>', 'https://danbooru.donmai.us/post_sets/1234', internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-wiki-page-id-link" href="/wiki_pages/1234">wiki #1234</a></p>', 'https://danbooru.donmai.us/wiki_pages/1234', internal_domains: %w[danbooru.donmai.us])

    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/posts/1234#comment_5678">https://danbooru.donmai.us/posts/1234#comment_5678</a></p>', 'https://danbooru.donmai.us/posts/1234#comment_5678', domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/pools/1234?page=2">https://danbooru.donmai.us/pools/1234?page=2</a></p>', 'https://danbooru.donmai.us/pools/1234?page=2', domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/post_sets/1234?page=2">https://danbooru.donmai.us/post_sets/1234?page=2</a></p>', 'https://danbooru.donmai.us/post_sets/1234?page=2', domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/forums/topics/1234?page=2">https://danbooru.donmai.us/forums/topics/1234?page=2</a></p>', 'https://danbooru.donmai.us/forums/topics/1234?page=2', domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/forums/topics/1234#forum_post_5678">https://danbooru.donmai.us/forums/topics/1234#forum_post_5678</a></p>', 'https://danbooru.donmai.us/forums/topics/1234#forum_post_5678', domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/wiki_pages/1234#see-also">https://danbooru.donmai.us/wiki_pages/1234#see-also</a></p>', 'https://danbooru.donmai.us/wiki_pages/1234#see-also', domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])
    assert_parse('<p><a class="dtext-link" href="https://danbooru.donmai.us/wiki_pages/touhou#see-also">https://danbooru.donmai.us/wiki_pages/touhou#see-also</a></p>', 'https://danbooru.donmai.us/wiki_pages/touhou#see-also', domain: "danbooru.donmai.us", internal_domains: %w[danbooru.donmai.us])

    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=touhou">touhou</a></p>', 'https://danbooru.donmai.us/wiki_pages/touhou', internal_domains: %w[danbooru.donmai.us])
  end

  def test_old_style_links
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com">test</a></p>', '"test":http://test.com')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="Http://test.com">test</a></p>', '"test":Http://test.com')

    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', '"http://test.com":http://test.com')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a></p>', '"http://test.com":[http://test.com]')

    assert_parse('<p><a class="dtext-link" href="#">test</a></p>', '"test":#')
    assert_parse('<p><a class="dtext-link" href="/">test</a></p>', '"test":/')
    assert_parse('<p><a class="dtext-link" href="/x">test</a></p>', '"test":/x')
    assert_parse('<p><a class="dtext-link" href="//">test</a></p>', '"test"://')

    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">test</a></p>', '"test"://example.com')
    assert_parse('<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">test</a></p>', '""test"://example.com')
    assert_parse('<p>&quot;te<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">st</a></p>', '"te"st"://example.com')

    assert_parse('<p>&quot;test&quot;&quot;://example.com</p>', '"test""://example.com')
  end

  def test_old_style_links_with_inline_tags
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com"><em>test</em></a></p>', '"[i]test[/i]":http://test.com')
  end

  def test_old_style_links_with_nested_links
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com">post #1</a></p>', '"post #1":http://test.com')
  end

  def test_old_style_links_with_special_entities
    assert_parse('<p>&quot;1&quot; <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://three.com">2 &amp; 3</a></p>', '"1" "2 & 3":http://three.com')
  end

  def test_new_style_links
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com">test</a></p>', '"test":[http://test.com]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="Http://test.com">test</a></p>', '"test":[Http://test.com]')

    assert_parse('<p><a class="dtext-link" href="#">test</a></p>', '"test":[#]')
    assert_parse('<p><a class="dtext-link" href="/">test</a></p>', '"test":[/]')
    assert_parse('<p><a class="dtext-link" href="/x">test</a></p>', '"test":[/x]')
    assert_parse('<p><a class="dtext-link" href="//">test</a></p>', '"test":[//]')

    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">test</a></p>', '"test":[//example.com]')
  end

  def test_new_style_links_with_inline_tags
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com/(parentheses)"><em>test</em></a></p>', '"[i]test[/i]":[http://test.com/(parentheses)]')
  end

  def test_new_style_links_with_nested_links
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com">post #1</a></p>', '"post #1":[http://test.com]')
  end

  def test_new_style_links_with_parentheses
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com/(parentheses)">test</a></p>', '"test":[http://test.com/(parentheses)]')
    assert_parse('<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com/(parentheses)">test</a>)</p>', '("test":[http://test.com/(parentheses)])')
    assert_parse('<p>[<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com/(parentheses)">test</a>]</p>', '["test":[http://test.com/(parentheses)]]')
  end

  def test_backwards_markdown_links
    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">test</a>', '[http://example.com](test)')
    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="Http://example.com">test</a>', '[Http://example.com](test)')
    assert_inline_parse('<em>one</em>(two)', '[i]one[/i](two)')

    assert_inline_parse('<a class="dtext-link" href="/posts">test</a>', "[/posts](test)")
    assert_inline_parse("[/b](test)", "[/b](test)")
    assert_inline_parse("[/b]blah[/b](test)", "[/b]blah[/b](test)")

    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">foo</a>(test)', '"foo":[http://example.com](test)')
    assert_inline_parse('<a class="dtext-link" href="/posts">foo</a>(test)', '"foo":[/posts](test)')
    assert_inline_parse('<a class="dtext-link" href="/posts">foo</a>(/test)', '"foo":[/posts](/test)')
    assert_inline_parse('<a class="dtext-link" href="/b">foo</a>(/test)', '"foo":[/b](/test)')
    #assert_inline_parse('<strong>"foo":</strong>(/test)', '[b]"foo":[/b](/test)')
    #assert_inline_parse('<strong>"foo":</strong>(/test)[/b]', '[b]"foo":[/b](/test)[/b]')

    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://foo.com">http://bar.com</a>', '[http://foo.com](http://bar.com)')
    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://foo.com">/bar</a>', '[http://foo.com](/bar)')
    assert_inline_parse('<a class="dtext-link" href="/foo">http://bar.com</a>', '[/foo](http://bar.com)')
    assert_inline_parse('<a class="dtext-link" href="/foo">/bar</a>', '[/foo](/bar)')
    assert_inline_parse('[/b](<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://bar.com">http://bar.com</a>)', '[/b](http://bar.com)')
    assert_inline_parse("[/b](/bar)", '[/b](/bar)')
    assert_inline_parse("<strong>foo</strong>(/bar)", '[b]foo[/b](/bar)')
    assert_inline_parse("<strong>foo</strong>(bar)", '[b]foo[/b](bar)')

    assert_inline_parse(CGI.escapeHTML('[blah](test)'), '[blah](test)')
    assert_inline_parse(CGI.escapeHTML('[](test)'), '[](test)')
  end

  def test_markdown_links
    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">test</a>', "[test](http://example.com)")
    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="Http://example.com">test</a>', "[test](Http://example.com)")

    assert_inline_parse('[test](<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>', "[test](http://example.com")
    assert_inline_parse('[test](<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/foo">http://example.com/foo</a> bar)', "[test](http://example.com/foo bar)")

    assert_inline_parse("(http://example.com)", "[nodtext](http://example.com)[/nodtext]")
    assert_inline_parse("(http://example.com)", "[nodtext](http://example.com)")
    assert_inline_parse('<strong>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>)</strong>', "[b](http://example.com)[/b]")
    assert_inline_parse('<strong>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>)</strong>', "[b](http://example.com)")
    assert_inline_parse('[url](<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>)[/url]', "[url](http://example.com)[/url]")
    assert_inline_parse('[url](<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>)', "[url](http://example.com)")
    assert_inline_parse('<strong>foo</strong>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>)', "[b]foo[/b](http://example.com)")
    assert_inline_parse('<a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=foo">foo</a>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>)', "[[foo]](http://example.com)")

    assert_inline_parse('<a class="dtext-link" href="/posts/1">test</a>', "[test](/posts/1)")
    assert_inline_parse('<a class="dtext-link" href="#foo">test</a>', "[test](#foo)")

    assert_inline_parse("(/posts)", "[nodtext](/posts)[/nodtext]")
    assert_inline_parse("(/posts)", "[nodtext](/posts)")
    assert_inline_parse("<strong>(/posts)</strong>", "[b](/posts)[/b]")
    assert_inline_parse("<strong>(/posts)</strong>", "[b](/posts)")
    assert_inline_parse("<strong>foo</strong>(/posts)", "[b]foo[/b](/posts)")
    assert_inline_parse('<a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=foo">foo</a>(/posts)', "[[foo]](/posts)")

    assert_inline_parse('[test](/posts/1 2)', "[test](/posts/1 2)")
    assert_inline_parse('[test](#foo bar)', "[test](#foo bar)")
    assert_inline_parse('[test](/posts', "[test](/posts")
    assert_inline_parse('[test](#foo', "[test](#foo")
    assert_inline_parse('[test](foo)', "[test](foo)")

    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://foo.com">http://bar.com</a>', "[http://foo.com](http://bar.com)")
  end

  def test_html_links
    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">test</a>', '<a href="http://example.com">test</a>')
    assert_inline_parse('<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="Http://example.com">test</a>', '<a href="Http://example.com">test</a>')
    assert_inline_parse('<a class="dtext-link" href="/x">a <em>b</em> c</a>', '<a href="/x">a [i]b[/i] c</a>')

    assert_parse('<p><a class="dtext-link" href="#">test</a></p>', '<a href="#">test</a>')
    assert_parse('<p><a class="dtext-link" href="/">test</a></p>', '<a href="/">test</a>')
    assert_parse('<p><a class="dtext-link" href="/x">test</a></p>', '<a href="/x">test</a>')
    assert_parse('<p><a class="dtext-link" href="//">test</a></p>', '<a href="//">test</a>')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://x">test</a></p>', '<a href="//x">test</a>')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://evil.com">test</a></p>', '<a href="//evil.com">test</a>')

    assert_inline_parse(CGI.escapeHTML('<a href="">test</a>'), '<a href="">test</a>')
    assert_inline_parse(CGI.escapeHTML('<a id="foo" href="">test</a>'), '<a id="foo" href="">test</a>')
  end

  def test_bbcode_links
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a></p>', '[url]http://example.com[/url]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a></p>', '[URL]http://example.com[/URL]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a></p>', '[url] http://example.com [/url]')

    assert_parse('<p><a class="dtext-link" href="/posts">/posts</a></p>', '[url]/posts[/url]')
    assert_parse('<p><a class="dtext-link" href="/posts">posts</a></p>', '[url=/posts]posts[/url]')

    assert_parse('<p>[url=<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>]example</p>', '[url=http://example.com]example')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a>blah[/url]</p>', '[url=http://example.com]example[/url]blah[/url]')

    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></p>', %{[url=http://example.com]example[/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></p>', %{[url="http://example.com"]example[/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></p>', %{[url='http://example.com']example[/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></p>', %{[url=http://example.com] example [/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com"><em>example</em></a></p>', %{[url=http://example.com][i]example[/i][/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com"><em>example</em></a></p>', %{[url=http://example.com] <i>example</i> [/url]})

    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></p>', %{[url = http://example.com ]example[/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></p>', %{[url = "http://example.com" ]example[/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></p>', %{[url = 'http://example.com' ]example[/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">example</a></p>', %{[url = 'http://example.com' ] example [/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com"><em>example</em></a></p>', %{[url = "http://example.com" ] [i]example[/i] [/url]})
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com"><em>example</em></a></p>', %{[url = "http://example.com" ] <i>example</i> [/url]})

    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://danbooru.donmai.us/posts/1234?q=touhou#comment-456">http://danbooru.donmai.us/posts/1234?q=touhou#comment-456</a></p>', '[url]http://danbooru.donmai.us/posts/1234?q=touhou#comment-456[/url]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://danbooru.donmai.us/posts/1234?q=touhou#comment-456">blah</a></p>', '[url=http://danbooru.donmai.us/posts/1234?q=touhou#comment-456]blah[/url]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://danbooru.donmai.us/posts/1234?q=touhou#comment-456">blah</a></p>', '[url="http://danbooru.donmai.us/posts/1234?q=touhou#comment-456"]blah[/url]')

    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://buzmon.net">Hentai</a>Story</p>', '[URL=http://buzmon.net]Hentai [/URL]Story')
    assert_parse('<p>foo<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://google.com">foo  bar</a>bar</p>', 'foo[url=http://google.com] foo  bar [/url]bar')

    assert_parse('<p>[url]nonurl[/url]</p>', '[url]nonurl[/url]')
    assert_parse('<p>[url=nonurl]blah[/url]</p>', '[url=nonurl]blah[/url]')
    assert_parse('<p>[url][/url]</p>', '[url][/url]')
    assert_parse('<p>[url=<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://google.com">http://google.com</a>][/url]</p>', '[url=http://google.com][/url]')
    assert_parse('<p>[url=<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://google.com">http://google.com</a>] [/url]</p>', '[url=http://google.com] [/url]')
    assert_parse('<p>[url=<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://google.com">http://google.com</a>]     [/url]</p>', '[url=http://google.com]     [/url]')
  end

  def test_fragment_only_urls
    assert_parse('<p><a class="dtext-link" href="#toc">test</a></p>', '"test":#toc')
    assert_parse('<p><a class="dtext-link" href="#toc">test</a></p>', '"test":[#toc]')
  end

  def test_auto_url_boundaries
    assert_parse('<p>a （<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>） b</p>', 'a （http://test.com） b')
    assert_parse('<p>a 〜<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>〜 b</p>', 'a 〜http://test.com〜 b')
    assert_parse('<p>a <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://test.com">http://test.com</a>　 b</p>', 'a http://test.com　 b')
    assert_parse('<p>a <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://dic.pixiv.net/a/姉ヶ崎寧々">http://dic.pixiv.net/a/姉ヶ崎寧々</a> b</p>', 'a http://dic.pixiv.net/a/姉ヶ崎寧々 b')

    assert_parse('<p>https:///</p>', 'https:///')
    assert_parse('<p>https://#</p>', 'https://#')
    assert_parse('<p>https://?</p>', 'https://?')
    assert_parse('<p>https://:</p>', 'https://:')
    #assert_parse('<p>&lt;https://?&gt;</p>', '<https://?>')
    #assert_parse('<p>&lt;https://:&gt;</p>', '<https://:>')

    # boundary chars
    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com:80">http://example.com:80</a></p>}, %{http://example.com:80})
    assert_parse(%{<p>'<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>'</p>}, %{'http://example.com'})
    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>!</p>}, %{http://example.com!})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>&quot;</p>}, %{"http://example.com"})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>&quot;:</p>}, %{"http://example.com":})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>&quot;&gt;</p>}, %{"http://example.com">})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>)</p>}, %{(http://example.com)})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>).</p>}, %{(http://example.com).})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>),</p>}, %{(http://example.com),})
    assert_parse(%{<p>「<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>」</p>}, %{「http://example.com」})
    assert_parse(%{<p>（<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>）</p>}, %{（http://example.com）})
    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com">http://example.com</a>[/quote]</p>}, %{http://example.com[/quote]})

    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com:80/path">http://example.com:80/path</a></p>}, %{http://example.com:80/path})
    assert_parse(%{<p>'<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>'</p>}, %{'http://example.com/path'})
    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path!">http://example.com/path!</a></p>}, %{http://example.com/path!})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>&quot;</p>}, %{"http://example.com/path"})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>&quot;:</p>}, %{"http://example.com/path":})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>)</p>}, %{(http://example.com/path)})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>).</p>}, %{(http://example.com/path).})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>),</p>}, %{(http://example.com/path),})
    assert_parse(%{<p>「<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>」</p>}, %{「http://example.com/path」})
    assert_parse(%{<p>（<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>）</p>}, %{（http://example.com/path）})
    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path">http://example.com/path</a>[/quote]</p>}, %{http://example.com/path[/quote]})

    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com:80/path?query">http://example.com:80/path?query</a></p>}, %{http://example.com:80/path?query})
    assert_parse(%{<p>'<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>'</p>}, %{'http://example.com/path?query'})
    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query!">http://example.com/path?query!</a></p>}, %{http://example.com/path?query!})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>&quot;</p>}, %{"http://example.com/path?query"})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>&quot;:</p>}, %{"http://example.com/path?query":})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>)</p>}, %{(http://example.com/path?query)})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>).</p>}, %{(http://example.com/path?query).})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>),</p>}, %{(http://example.com/path?query),})
    assert_parse(%{<p>「<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>」</p>}, %{「http://example.com/path?query」})
    assert_parse(%{<p>（<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>）</p>}, %{（http://example.com/path?query）})
    #assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query">http://example.com/path?query</a>[/quote]</p>}, %{http://example.com/path?query[/quote]})

    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com:80/path?query#fragment">http://example.com:80/path?query#fragment</a></p>}, %{http://example.com:80/path?query#fragment})
    assert_parse(%{<p>'<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>'</p>}, %{'http://example.com/path?query#fragment'})
    assert_parse(%{<p>'<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment!">http://example.com/path?query#fragment!</a></p>}, %{'http://example.com/path?query#fragment!})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>&quot;</p>}, %{"http://example.com/path?query#fragment"})
    assert_parse(%{<p>&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>&quot;:</p>}, %{"http://example.com/path?query#fragment":})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>)</p>}, %{(http://example.com/path?query#fragment)})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>).</p>}, %{(http://example.com/path?query#fragment).})
    assert_parse(%{<p>(<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>),</p>}, %{(http://example.com/path?query#fragment),})
    assert_parse(%{<p>「<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>」</p>}, %{「http://example.com/path?query#fragment」})
    assert_parse(%{<p>（<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>）</p>}, %{（http://example.com/path?query#fragment）})
    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://example.com/path?query#fragment">http://example.com/path?query#fragment</a>[/quote]</p>}, %{http://example.com/path?query#fragment[/quote]})

    # misc
    assert_parse('<p>http://<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://cramnuts.web.fc2.com/index.html">http://cramnuts.web.fc2.com/index.html</a></p>', 'http://http://cramnuts.web.fc2.com/index.html')
    assert_parse('<p>（アートスペースエーワン)<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://www.artspace-a1.com">http://www.artspace-a1.com</a>)にてこちらの原画他、</p>', '（アートスペースエーワン)http://www.artspace-a1.com)にてこちらの原画他、')
    assert_parse('<p>&quot;Referer: <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://www.pixiv.net">http://www.pixiv.net</a>&quot;.</p>', '"Referer: http://www.pixiv.net".')
    assert_parse('<p>[url=&quot;<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://customseekdeal.com">http://customseekdeal.com</a>&quot;]custom</p>', '[url="http://customseekdeal.com"]custom')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://en.wikipedia.org/wiki/Natsume_Sōseki">http://en.wikipedia.org/wiki/Natsume_Sōseki</a></p>', 'http://en.wikipedia.org/wiki/Natsume_Sōseki')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://example.com">https://example.com</a>@gmail.com</p>', 'https://example.com@gmail.com')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://transformers.wikia.com/wiki/Starscream_(Movie)">http://transformers.wikia.com/wiki/Starscream_(Movie)</a>,</p>', 'http://transformers.wikia.com/wiki/Starscream_(Movie),')

    # trailing tags
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://www.pixiv.net">Pixiv</a>.[/quote]</p>', '"Pixiv":http://www.pixiv.net.[/quote]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://edwinhuang.tumblr.com">http://edwinhuang.tumblr.com</a>[/quote]</p>', 'http://edwinhuang.tumblr.com[/quote]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://edwinhuang.tumblr.com/">http://edwinhuang.tumblr.com/</a>[/quote]</p>', 'http://edwinhuang.tumblr.com/[/quote]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://edwinhuang.tumblr.com">http://edwinhuang.tumblr.com</a>&lt;/quote&gt;</p>', 'http://edwinhuang.tumblr.com</quote>')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://edwinhuang.tumblr.com/">http://edwinhuang.tumblr.com/</a>&lt;/quote&gt;</p>', 'http://edwinhuang.tumblr.com/</quote>')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://www.youtube.com/watch#!v=qvRqnd4ymus">http://www.youtube.com/watch#!v=qvRqnd4ymus</a><strong>&amp;feature=related</strong></p>', 'http://www.youtube.com/watch#!v=qvRqnd4ymus[b]&feature=related[/b]')

    # domains
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://www15.oekakibbs.com">http://www15.oekakibbs.com</a>./bbs/sousyou7676/oekakibbs.cgi</p>', 'http://www15.oekakibbs.com./bbs/sousyou7676/oekakibbs.cgi') # XXX technically legal, but usually a typo
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://www.tv-tokyo.co.jp.e.ck.hp.transer.com/samaazu2/">http://www.tv-tokyo.co.jp.e.ck.hp.transer.com/samaazu2/</a></p>', 'http://www.tv-tokyo.co.jp.e.ck.hp.transer.com/samaazu2/')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://ガールズシンフォニー.攻略wiki.com">http://ガールズシンフォニー.攻略wiki.com</a></p>', 'http://ガールズシンフォニー.攻略wiki.com')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://mn_nihongo.tripod.com/shoji_fusuma.html">http://mn_nihongo.tripod.com/shoji_fusuma.html</a></p>', 'http://mn_nihongo.tripod.com/shoji_fusuma.html')

    assert_parse(%{<p>(Couln't GET <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://danbooru.donm">http://danbooru.donm</a>&quot;)</p>}, %{(Couln't GET http://danbooru.donm")}) # XXX bad TLD
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://cid-9b1c4a4c378e913d.skyd">http://cid-9b1c4a4c378e913d.skyd</a>...nga/joelansx_02_flash.zip</p>', 'http://cid-9b1c4a4c378e913d.skyd...nga/joelansx_02_flash.zip') # XXX bad TLD
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://doujinshi.mugimugi">http://doujinshi.mugimugi</a>...thor/3745/Andou-Hiroyuki/</p>', 'http://doujinshi.mugimugi...thor/3745/Andou-Hiroyuki/') # XXX bad TLD
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://danbooru.donmai.ushttps">http://danbooru.donmai.ushttps</a>://s3.amazonaws.com/danbooru/cropped/small/86c7b94e2fc32bf4b25a25eed11bbe90.jpg</p>', 'http://danbooru.donmai.ushttps://s3.amazonaws.com/danbooru/cropped/small/86c7b94e2fc32bf4b25a25eed11bbe90.jpg') # XXX bad TLD

    assert_parse('<p>source:http://*.pixiv.net/img/una_k/</p>', 'source:http://*.pixiv.net/img/una_k/')
    assert_parse('<p>src^=&quot;http://img&quot;</p>', 'src^="http://img"')
    assert_parse('<p>replace http:// with https://.&quot;</p>', 'replace http:// with https://."')
    assert_parse('<p>http://tegaki/pipa.jp/248411/</p>', 'http://tegaki/pipa.jp/248411/')
    assert_parse('<p>http://li246-243/maintenance/user/password_reset/&lt;snip&gt;</p>', 'http://li246-243/maintenance/user/password_reset/<snip>')
    assert_parse('<p>&quot;Buy this print&quot;:http://monster_print</p>', '"Buy this print":http://monster_print')
    assert_parse('<p>https://pawhttps://danbooru.donmai.us/posts/3305764#oo.net/kamoseiro</p>', 'https://pawhttps://danbooru.donmai.us/posts/3305764#oo.net/kamoseiro')
    assert_parse('<p>https://&lt;artist name&gt;.artstation.com/projects/&lt;shortcode&gt;</p>', 'https://<artist name>.artstation.com/projects/<shortcode>')
    assert_parse('<p>http://i[1-2].pixiv.net/img[0-9]+/img/[userloginname]</p>', 'http://i[1-2].pixiv.net/img[0-9]+/img/[userloginname]')
    assert_parse('<p>http://img*.pixiv.net/img/pad*</p>', 'http://img*.pixiv.net/img/pad*')
    assert_parse('<p>http://img[0-9][0-9].pixiv.net/img/[a-z0-9]+/[0-9]+.[png|PNG|jpeg|jpg|JPEG|JPG|gif|GIF]</p>', 'http://img[0-9][0-9].pixiv.net/img/[a-z0-9]+/[0-9]+.[png|PNG|jpeg|jpg|JPEG|JPG|gif|GIF]')
    assert_parse('<p>http://nicov...</p>', 'http://nicov...')
    assert_parse('<p>http://localhost:&lt;port&gt;/pixanim?ID=&lt;id&gt;&amp;method=&lt;method&gt;</p>', 'http://localhost:<port>/pixanim?ID=<id>&method=<method>')
    assert_parse('<p>Star! http://instagram instagram.com/lariennechan/</p>', 'Star! http://instagram instagram.com/lariennechan/')
    assert_parse('<p>&quot;like so&quot;:http://about:blank</p>', '"like so":http://about:blank')
    assert_parse('<p>&quot;twitter/meiwari&quot;:https://twitter/meiwari</p>', '"twitter/meiwari":https://twitter/meiwari')
    assert_parse('<p>curl cookies.txt -d &quot;post[tags]=tag1 tag_2 tag_tag&amp;post[source]=http://yourip/path/to/your/img.jpg&quot;</p>', 'curl cookies.txt -d "post[tags]=tag1 tag_2 tag_tag&post[source]=http://yourip/path/to/your/img.jpg"')
    assert_parse('<p>hxxp://www.age.jp/~kw</p>', 'hxxp://www.age.jp/~kw')
    assert_parse('<p>ttp://alem.sakura.ne.jp/</p>', 'ttp://alem.sakura.ne.jp/')
    assert_parse('<p>file://9dcd08b05cdc11e79eb675210c777bab.jpg</p>', 'file://9dcd08b05cdc11e79eb675210c777bab.jpg')
    assert_parse('<p>https://username@gmail.com</p>', 'https://username@gmail.com')
    assert_parse('<p>http://myhost:3000/post/create.xml?tags=blah&amp;source=http://someurl</p>', 'http://myhost:3000/post/create.xml?tags=blah&source=http://someurl') # XXX should work
    assert_parse('<p>https://user:pass@example.com</p>', 'https://user:pass@example.com') # XXX should work

    # trailing CJK
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://www.toranoana.jp/mailorder/article/04/0030/25/75/040030257564.html">http://www.toranoana.jp/mailorder/article/04/0030/25/75/040030257564.html</a>」<span class="dtext-note">Author</span></p>', 'http://www.toranoana.jp/mailorder/article/04/0030/25/75/040030257564.html」[note]Author')
    assert_parse('<p>の「<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://color-t.net/">http://color-t.net/</a>」か</p>', 'の「http://color-t.net/」か')
    assert_parse('<p>続・小鳥さんのGM奮闘記（<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://www.nicovideo.jp/watch/sm9767866">http://www.nicovideo.jp/watch/sm9767866</a>）の舞さんを描かせてもらいました。</p>', '続・小鳥さんのGM奮闘記（http://www.nicovideo.jp/watch/sm9767866）の舞さんを描かせてもらいました。')
  end

  def test_old_style_link_boundaries
    assert_parse('<p>a 「<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com">title</a>」 b</p>', 'a 「"title":http://test.com」 b')
  end

  def test_new_style_link_boundaries
    assert_parse('<p>a 「<a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://test.com">title</a>」 b</p>', 'a 「"title":[http://test.com]」 b')
  end

  def test_lists
    assert_parse('<ul><li>a</li></ul>', '* a')
    assert_parse('<ul><li>a</li><li>b</li></ul>', "* a\n* b")
    assert_parse('<ul><li>a</li><li>b</li><li>c</li></ul>', "* a\n* b\n* c")
    assert_parse('<ul><li>a</li></ul>', "* a\n ")

    assert_parse('<ul><li>a</li><li>b</li></ul>', "* a\r\n* b")
    assert_parse('<ul><li>a</li></ul><ul><li>b</li></ul>', "* a\n\n* b")
    assert_parse('<ul><li>a</li><li>b</li><li>c</li></ul>', "* a\r\n* b\r\n* c")

    assert_parse('<ul><li>a</li><ul><li>b</li></ul></ul>', "* a\n** b")
    assert_parse('<ul><li>a</li><ul><ul><li>b</li></ul></ul></ul>', "* a\n*** b")
    assert_parse('<ul><li>a</li><ul><li>b</li><ul><li>c</li></ul></ul></ul>', "* a\n** b\n*** c")
    assert_parse('<ul><ul><ul><li>a</li></ul><li>b</li></ul><li>c</li></ul>', "*** a\n** b\n* c")
    assert_parse('<ul><ul><ul><li>a</li></ul></ul><li>b</li></ul>', "*** a\n* b")
    assert_parse('<ul><ul><ul><li>a</li></ul></ul></ul>', "*** a")

    assert_parse('<ul><li>a</li></ul><p>b</p><ul><li>c</li></ul>', "* a\nb\n* c")

    assert_parse('<p>a<br>b</p><ul><li>c</li><li>d</li></ul>', "a\nb\n* c\n* d")
    assert_parse('<p>a</p><ul><li>b</li></ul><p>c</p><ul><li>d</li></ul><p>e</p><p>another one</p>', "a\n* b\nc\n* d\ne\n\nanother one")
    assert_parse('<p>a</p><ul><li>b</li></ul><p>c</p><ul><ul><li>d</li></ul></ul><p>e</p><p>another one</p>', "a\n* b\nc\n** d\ne\n\nanother one")
    assert_parse('<p>a</p><ul><li>b</li></ul><p>c</p><ul><ul><li>d</li></ul></ul><p>e</p><p>another one</p>', "a\n* b\nc\n** d\ne\n\nanother one")

    assert_parse('<ul><li><a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/1">post #1</a></li></ul>', "* post #1")

    assert_parse('<ul><li><em>a</em></li><li>b</li></ul>', "* [i]a[/i]\n* b")
    assert_parse('<ul><li><em>a</em></li><li>b</li></ul>', "* [i]a\n* b")

    assert_parse('<ul><ul><li><em>a</em></li></ul><li>b</li></ul>', "** [i]a\n* b")
    assert_parse('<ul><li><em>a</em></li></ul><ul><li>b</li></ul>', "* [i]a\n\n* b")
    assert_parse('<p><em>a</em></p><ul><li>b</li><li>c</li></ul>', "[i]a\n* b\n* c")

    # assert_parse('<ul><li></li></ul><h4>See also</h4><ul><li>a</li></ul>', "* h4. See also\n* a")
    assert_parse('<ul><li>h4. See also</li><li>a</li></ul>', "* h4. See also\n* a") # XXX wrong?

    assert_parse('<ul><li>a</li></ul><h4>See also</h4>', "* a\nh4. See also")
    assert_parse('<h4><em>See also</em></h4><ul><li>a</li></ul>', "h4. [i]See also\n* a")
    assert_parse('<ul><li><em>a</em></li></ul><h4>See also</h4>', "* [i]a\nh4. See also")

    assert_parse('<h4>See also</h4><ul><li>a</li></ul>', "h4. See also\n* a")
    assert_parse('<h4>See also</h4><ul><li>a</li><li>h4. External links</li></ul>', "h4. See also\n* a\n* h4. External links")

    assert_parse('<p>a</p><div class="spoiler"><ul><li>b</li><li>c</li></ul></div><p>d</p>', "a\n[spoilers]\n* b\n* c\n[/spoilers]\nd")

    assert_parse('<p>a</p><blockquote><ul><li>b</li><li>c</li></ul></blockquote><p>d</p>', "a\n[quote]\n* b\n* c\n[/quote]\nd")
    assert_parse('<p>a</p><details><summary></summary><div><ul><li>b</li><li>c</li></ul></div></details><p>d</p>', "a\n[section]\n* b\n* c\n[/section]\nd")

    assert_parse('<p>a</p><blockquote><ul><li>b</li><li>c</li></ul><p>d</p></blockquote>', "a\n[quote]\n* b\n* c\n\nd")
    assert_parse('<p>a</p><details><summary></summary><div><ul><li>b</li><li>c</li></ul><p>d</p></div></details>', "a\n[section]\n* b\n* c\n\nd")

    assert_parse('<ul><li>* * * *</li></ul>', "* * * * *") # XXX wrong
    assert_parse('<ul><li>Nosebleed *</li></ul>', "* Nosebleed *") # XXX wrong
    assert_parse('<blockquote><ul><ul><ul><li>said:</li></ul></ul></ul></blockquote>', "[quote] *** said:") # XXX wrong
    assert_parse('<div class="spoiler"><ul><li>It could also mean</li></ul></div>', "[spoiler] * It could also mean") # XXX wrong

    assert_parse('<p>*</p>', "*")
    assert_parse('<p>*a</p>', "*a")
    assert_parse('<p>***</p>', "***")
    assert_parse('<p>*<br>*<br>*</p>', "*\n*\n*")
    assert_parse('<p>* <br>blah</p>', "* \r\nblah")
    assert_parse('<p>* </p>', '* ')
  end

  def test_post_search_links
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "{{tag}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "{{ tag}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "{{tag }}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "{{ tag }}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tag1%20tag2">tag1 tag2</a></p>', "{{tag1 tag2}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tag1%20tag2">tag1 tag2</a></p>', "{{ tag1 tag2 }}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="https://danbooru.donmai.us/posts?tags=tag1%20tag2">tag1 tag2</a></p>', "{{tag1 tag2}}", base_url: "https://danbooru.donmai.us")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%3C3">&lt;3</a></p>', "{{<3}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%22%23%26%2B%3C%3E%3F">&quot;#&amp;+&lt;&gt;?</a></p>', '{{ "#&+<>?}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%E6%9D%B1%E6%96%B9">東方</a></p>', "{{東方}}")
    assert_parse('<p>use {{}}, like so: <a class="dtext-link dtext-post-search-link" href="/posts?tags=touhou">touhou</a></p>', "use {{}}, like so: {{touhou}}")

    assert_parse('<p>{<a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "{{{tag}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a>}</p>', "{{tag}}}")
    assert_parse('<p>{{<a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a>}}</p>', "{{{{tag}}}}")
    assert_parse('<p>{{tag1,<a class="dtext-link dtext-post-search-link" href="/posts?tags=tag2">tag2</a></p>', "{{tag1,{{tag2}}")

    assert_parse('<p>I like <a class="dtext-link dtext-post-search-link" href="/posts?tags=cat">cats</a>.</p>', "I like {{cat}}s.")
    assert_parse('<p>a <a class="dtext-link dtext-post-search-link" href="/posts?tags=cat">cat</a>\'s paw</p>', "a {{cat}}'s paw")
    assert_parse('<p>the <a class="dtext-link dtext-post-search-link" href="/posts?tags=60s">1960s</a>.</p>', "the 19{{60s}}.")
    assert_parse('<p>a <a class="dtext-link dtext-post-search-link" href="/posts?tags=c">bcd</a> e</p>', "a b{{c}}d e")
    assert_parse('<p>a <a class="dtext-link dtext-post-search-link" href="/posts?tags=c">bde</a> f</p>', "a b{{c|d}}e f")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=cd">abcdef</a><a class="dtext-link dtext-post-search-link" href="/posts?tags=gh">ghij</a></p>', "ab{{cd}}ef{{gh}}ij")

    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=long_hair">Long Hair</a></p>', "{{long_hair|Long Hair}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=long_hair">Long Hair</a></p>', "{{ long_hair | Long Hair }}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7C_%7C">foo|bar</a></p>', "{{ |_| | foo|bar }}")

    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tagme">tagme</a></p>', "{{tagme|}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=bb_%28fate%29">bb</a></p>', "{{bb_(fate)|}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=bb_%28fate%29">bb</a></p>', "{{bb_(fate)| }}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=bb_%28fate%29">bb</a></p>', "{{bb_(fate) |}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=bb_%28fate%29">bb</a></p>', "{{bb_(fate) | }}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=bb_%28swimsuit_mooncancer%29_%28fate%29">bb_(swimsuit_mooncancer)</a></p>', "{{bb_(swimsuit_mooncancer)_(fate)|}}")

    assert_parse('<p>{{smile | :} }}</p>', "{{smile | :} }}") # XXX should work
    #assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=smile">:}</a></p>', "{{ smile | :} }}")
    #assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=smile">:}</a></p>', "{{ smile |:} }}")
    #assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=smile">:</a>}</p>', "{{ smile | :}}}")
    #assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=smile">:</a>}</p>', "{{ smile |:}}}")

    #assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=smile">}}</a></p>', "{{ smile |}} }}")
    #assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=smile">}}</a></p>', "{{ smile | }} }}")
    #assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=smile">}</a>}</p>', "{{ smile |}}}}")
    #assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=smile">}</a>}</p>', "{{ smile | }}}}")

    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7C3">|3</a></p>', '{{|3}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7CD">|D</a></p>', '{{|D}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%3A%7C">:|</a></p>', '{{:|}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7C_%7C">|_|</a></p>', '{{|_|}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7C%7C_%7C%7C">||_||</a></p>', '{{||_||}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%5C%7C%7C%2F">\||/</a></p>', '{{\||/}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%3C%7C%3E_%3C%7C%3E">&lt;|&gt;_&lt;|&gt;</a></p>', '{{<|>_<|>}}')

    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7C3">blah</a></p>', '{{|3|blah}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7CD">blah</a></p>', '{{|D|blah}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%3A%7C">blah</a></p>', '{{:||blah}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7C_%7C">blah</a></p>', '{{|_||blah}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%7C%7C_%7C%7C">blah</a></p>', '{{||_|||blah}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%5C%7C%7C%2F">blah</a></p>', '{{\||/|blah}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%3C%7C%3E_%3C%7C%3E">blah</a></p>', '{{<|>_<|>|blah}}')

    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=-%7CD">-|D</a></p>', '{{-|D}}')
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=~%7CD">~|D</a></p>', '{{~|D}}')

    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tag#see-also">tag</a> <a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "[[tag#See also]] {{tag}}")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tag#see-also">Tag</a> <a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "[[tag#See also|Tag]] {{tag}}")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tag#see-also">tag</a> <a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "[[tag#see-also]] {{tag}}")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tag#see-also">Tag</a> <a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">tag</a></p>', "[[tag#see-also|Tag]] {{tag}}")
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=tag">Tag</a> <a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tag">tag</a></p>', "{{tag|Tag}} [[tag]]")

    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=%3A%7C">:|</a> foo <a class="dtext-link dtext-post-search-link" href="/posts?tags=bar">bar</a></p>', '{{:|}} foo {{bar}}')

    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=pool%3A%22Granblue%20Fantasy%20Unexpected%20Confession">Vane x Gran&quot;</a></p>', '{{pool:"Granblue Fantasy Unexpected Confession | Vane x Gran"}}') # XXX wrong
    assert_parse('<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=http%3A%2F%2Ftvtropes.org%2Fpmwiki%2Fpmwiki.php%2FMain%2FExactlyWhatItSaysOnTheTin">Exactly what it says on the tin</a></p>', "{{http://tvtropes.org/pmwiki/pmwiki.php/Main/ExactlyWhatItSaysOnTheTin|Exactly what it says on the tin}}") # XXX incorrect usage

    assert_parse('<p>{{}}</p>', "{{}}")
    assert_parse('<p>{{ }}</p>', "{{ }}")
    assert_parse('<p>{{1girl<br>solo}}</p>', "{{1girl\nsolo}}")
    assert_parse('<p>{{|bb_(fate)}}</p>', "{{|bb_(fate)}}")
  end

  def test_extra_newlines
    assert_parse('<p>a</p><p>b</p>', "a\n\n\n\n\n\n\nb\n\n\n\n")

    assert_parse('', "\n")
    assert_parse('', " \n")
    assert_parse('', "\n ")
    assert_parse('', " \n ")
    assert_parse('', "\n\n")
    assert_parse('', " \n\n")
    assert_parse('', "\n \n")
    assert_parse('', " \n \n ")

    assert_parse('<p>foo</p>', "foo\n")
    assert_parse('<ul><li>See also</li></ul>', "* See also\n")
    assert_parse('<ul><li>See also</li></ul>', "\n* See also\n")

    assert_parse('<h1>foo</h1>', "h1. foo\n")
    assert_parse('<h1>foo</h1>', "h1. foo\n\n")
    assert_parse('<h1>foo</h1>', "h1. foo\n   \n")
    assert_parse('<h1>foo</h1>', "h1. foo\n\n   ")

    assert_parse('<h1>foo</h1>', "\nh1. foo")
    assert_parse('<h1>foo</h1>', " \nh1. foo")
    assert_parse('<h1>foo</h1>', "\n\nh1. foo")
    assert_parse('<h1>foo</h1>', "   \n\nh1. foo")
    assert_parse('<h1>foo</h1>', "\n   \nh1. foo")
    assert_parse('<h1>foo</h1>', "   \n   \nh1. foo")

    assert_parse('<p>inline <em>foo</em></p>', "inline [i]foo\n")
    assert_parse('<p>inline <span class="spoiler">blah</span></p>', "inline [spoiler]blah\n")
    assert_parse('<p>inline <span class="dtext-note">blah</span></p>', "inline [note]blah\n")
    assert_parse("<p>inline <code>blah\n</code></p>", "inline [code]blah\n")
    assert_parse("<p>inline blah\n</p>", "inline [nodtext]blah\n")

    assert_parse('<p class="dtext-note">foo</p>', "[note]foo\n")
    assert_parse("<pre>foo\n</pre>", "[code]foo\n")
    assert_parse("<blockquote><p>foo</p></blockquote>", "[quote]foo\n")
    assert_parse("<details><summary></summary><div><p>foo</p></div></details>", "[section]foo\n")
    assert_parse("<p>foo\n</p>", "[nodtext]foo\n") # XXX should replace newlines

    assert_parse('<p>[/i]<br>blah</p>', "[/i]\nblah\n")
    assert_parse('<p>[/code]<br>blah</p>', "[/code]\nblah\n")
    assert_parse('<p>[/nodtext]<br>blah</p>', "[/nodtext]\nblah\n")
    assert_parse('<p>[/th]<br>blah</p>', "[/th]\nblah\n")
    assert_parse('<p>[/td]<br>blah</p>', "[/td]\nblah\n")

    assert_parse('<p>[/note]<br>blah</p>', "[/note]\nblah\n")
    assert_parse('<p>[/spoiler]<br>blah</p>', "[/spoiler]\nblah\n")
    assert_parse('<p>[/section]<br>blah</p>', "[/section]\nblah\n")

    assert_parse("<p>[/quote]<br>blah</p>", "[/quote]\nblah\n")

    assert_parse('<blockquote><ul><li>foo</li><li>bar</li></ul></blockquote>', "[quote]\n* foo\n* bar\n[/quote]")
    assert_parse('<blockquote><p>[/section]<br>blah</p></blockquote>', "[quote][/section]\nblah\n")

    assert_parse('<table class="striped"><tr><td><br>foo</td></tr></table>', "\n[table]\n[tr]\n[td]\nfoo\n[/td]\n[/tr]\n[/table]\n") # XXX wrong

    assert_parse('<p class="dtext-note">foo</p>', "[note]foo\n[/note]")
    assert_parse('<p class="dtext-note"><br>foo</p>', "[note]\nfoo\n[/note]") # XXX wrong
    assert_parse('<p class="dtext-note"><br>foo</p>', "[note]\nfoo[/note]") # XXX wrong

    assert_parse('<p>inline <span class="dtext-note">foo</span></p>', "inline [note]foo\n[/note]")
    assert_parse('<p>inline <span class="dtext-note">foo</span> bar</p>', "inline [note]foo\n[/note] bar") # XXX wrong?
    assert_parse('<p>inline <span class="dtext-note"><br>foo</span> bar</p>', "inline [note]\nfoo[/note] bar") # XXX wrong?
    assert_parse('<p>inline <span class="dtext-note"><br>foo</span> bar</p>', "inline [note]\nfoo\n[/note] bar") # XXX wrong?

    assert_parse('<pre>blah</pre><p>blah</p>', "[code]blah[/code] \nblah")

    assert_parse('<div class="spoiler"><p>blah</p></div>', "[spoiler]blah[/spoiler]")
    assert_parse('<div class="spoiler"><p>blah</p></div>', "[spoiler]blah[/spoiler] ")
    assert_parse('<div class="spoiler"><p>blah</p></div>', "[spoiler]\nblah\n[/spoiler]")
    assert_parse('<div class="spoiler"><p>blah</p></div>', "[spoiler]\nblah\n[/spoiler] ")

    assert_parse('<p>one</p><div class="spoiler"><p>two</p></div><div class="spoiler"><p>three</p></div>', "one\n\n[spoiler]two[/spoiler]\n[spoiler]three[/spoiler]")
    assert_parse('<p>one</p><div class="spoiler"><p>two</p></div><div class="spoiler"><p>three</p></div>', "one\n\n[spoiler]two[/spoiler]\n\n[spoiler]three[/spoiler]")
    assert_parse('<p>one</p><div class="spoiler"><p>two</p></div><div class="spoiler"><p>three</p></div>', "one\n \n[spoiler]two[/spoiler]\n \n[spoiler]three[/spoiler]")
    assert_parse('<p>one</p><div class="spoiler"><p>two</p></div><div class="spoiler"><p>three</p></div>', "one\n \n[spoiler]two[/spoiler]\n[spoiler]three[/spoiler]")
    assert_parse('<p>one</p><div class="spoiler"><p>two</p></div><div class="spoiler"><p>three</p></div>', "one\n \n[spoiler]two[/spoiler]\n\n[spoiler]three[/spoiler]")
    assert_parse('<p>one</p><div class="spoiler"><p>two</p></div><div class="spoiler"><p>three</p></div>', "one\n \n[spoiler]two[/spoiler]\n \n[spoiler]three[/spoiler]")
  end

  def test_complex_links_1
    assert_parse("<p><a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/1\">2 3</a> | <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/4\">5 6</a></p>", "[[1|2 3]] | [[4|5 6]]")
  end

  def test_complex_links_2
    assert_parse("<p>Tags <strong>(<a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=howto%3Atag\">Tagging Guidelines</a> | <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=howto%3Atag_checklist\">Tag Checklist</a> | <a rel=\"nofollow\" class=\"dtext-link dtext-wiki-link\" href=\"/wiki_pages/show_or_new?title=tag_groups\">Tag Groups</a>)</strong></p>", "Tags [b]([[howto:tag|Tagging Guidelines]] | [[howto:tag_checklist|Tag Checklist]] | [[Tag Groups]])[/b]")
  end

  def test_note_id_link
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-note-id-link" href="/notes/1234">note #1234</a></p>', "note #1234")
  end

  def test_table
    assert_parse("<table class=\"striped\"><tr><td>text</td></tr></table>", "[table][tr][td]text[/td][/tr][/table]")

    assert_parse("<table class=\"striped\"><thead><tr><th>header</th></tr></thead><tbody><tr><td><a class=\"dtext-link dtext-id-link dtext-post-id-link\" href=\"/posts/100\">post #100</a></td></tr></tbody></table>", "[table][thead][tr][th]header[/th][/tr][/thead][tbody][tr][td]post #100[/td][/tr][/tbody][/table]")
    assert_parse("<table class=\"striped\"><thead><tr><th>header</th></tr></thead><tbody><tr><td><a class=\"dtext-link dtext-id-link dtext-post-id-link\" href=\"/posts/100\">post #100</a></td></tr></tbody></table>", "[table]\n[thead]\n[tr]\n[th]header[/th][/tr][/thead][tbody][tr][td]post #100[/td][/tr][/tbody][/table]")

    assert_parse('<p>inline</p><table class="striped"><tr><td>text</td></tr></table>', "inline\n\n[table][tr][td]text[/td][/tr][/table]")
    assert_parse("<p><em>inline</em></p><table class=\"striped\"><tr><td>text</td></tr></table>", "[i]inline\n\n[table][tr][td]text[/td][/tr][/table]")

    assert_parse('<p>inline</p><table class="striped"><tr><td>text</td></tr></table>', "inline\n[table][tr][td]text[/td][/tr][/table]")
    assert_parse("<p><em>inline</em></p><table class=\"striped\"><tr><td>text</td></tr></table>", "[i]inline\n[table][tr][td]text[/td][/tr][/table]")

    assert_parse('<p>inline[table][tr][td]text[/td][/tr][/table]</p>', "inline[table][tr][td]text[/td][/tr][/table]")
    assert_parse('<p><em>inline[table][tr][td]text[/td][/tr][/table]</em></p>', "[i]inline[table][tr][td]text[/td][/tr][/table]")

    assert_parse('<h4>See also</h4><table class="striped"><tr><td>text</td></tr></table>', "h4. See also\n[table][tr][td]text[/td][/tr][/table]")
    assert_parse('<ul><li>list</li></ul><table class="striped"><tr><td>text</td></tr></table>', "* list\n[table][tr][td]text[/td][/tr][/table]")
    assert_parse('<div class="spoiler"><table class="striped"><tr><td>text</td></tr></table></div>', "[spoiler][table][tr][td]text[/td][/tr][/table][/spoiler]")
    assert_parse('<blockquote><table class="striped"><tr><td>text</td></tr></table></blockquote>', "[quote][table][tr][td]text[/td][/tr][/table][/quote]")
    assert_parse('<details><summary></summary><div><table class="striped"><tr><td>text</td></tr></table></div></details>', "[section][table][tr][td]text[/td][/tr][/table][/section]")

    assert_parse('<table class="striped"><td colspan="2">foo</td></table>', '[table][td colspan=2]foo[/td][/table]')
    assert_parse('<table class="striped"><td rowspan="3">foo</td></table>', '[table][td rowspan=3]foo[/td][/table]')

    assert_parse('<table class="striped"><td colspan="2">foo</td></table>', '[table][td colspan="2"]foo[/td][/table]')
    assert_parse('<table class="striped"><td colspan="2">foo</td></table>', "[table][td colspan='2']foo[/td][/table]")
    assert_parse('<table class="striped"><td colspan="2">foo</td></table>', '[table][td colspan = "2"]foo[/td][/table]')
    assert_parse('<table class="striped"><td colspan="3">foo</td></table>', '[table][td colspan=2 colspan=3]foo[/td][/table]')

    assert_parse('<table class="striped"><td colspan="2" rowspan="3">foo</td></table>', '[table][td colspan=2 rowspan=3]foo[/td][/table]')
    assert_parse('<table class="striped"><td colspan="2" rowspan="3">foo</td></table>', '[table][td rowspan=3 colspan=2]foo[/td][/table]')

    assert_parse('<table class="striped"></table>', '[table][td colspan=2rowspan=3]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', '[table][td colspan="2"rowspan="3"]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', '[table][tdcolspan]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', '[table][td colspan]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', '[table][td colspan=""]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', "[table][td colspan='']foo[/td][/table]")
    assert_parse('<table class="striped"></table>', '[table][td colspan=]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', '[table][td =2]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', '[table][td _colspan=2]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', "[table][td\ncolspan=2]foo[/td][/table]")
    assert_parse('<table class="striped"></table>', '[table][td colspan=2 ]foo[/td][/table]')
    assert_parse('<table class="striped"></table>', '[table][td ]foo[/td][/table]')

    assert_parse('<table class="striped"><td>foo</td></table>', '[table][td colspan="blah"]foo[/td][/table]')
    assert_parse('<table class="striped"><td>foo</td></table>', '[table][td colspan=blah]foo[/td][/table]')
    assert_parse('<table class="striped"><td>foo</td></table>', '[table][td id="blah"]foo[/td][/table]')
    assert_parse('<table class="striped"><td>foo</td></table>', '[table][td class="blah"]foo[/td][/table]')
    assert_parse('<table class="striped"><td>foo</td></table>', '[table][td style="blah"]foo[/td][/table]')
    assert_parse('<table class="striped"><td>foo</td></table>', '[table][td onclick="blah"]foo[/td][/table]')

    assert_parse('<table class="striped"><td align="left">foo</td></table>',    '[table][td align="left"]foo[/td][/table]')
    assert_parse('<table class="striped"><td align="center">foo</td></table>',  '[table][td align="center"]foo[/td][/table]')
    assert_parse('<table class="striped"><td align="right">foo</td></table>',   '[table][td align="right"]foo[/td][/table]')
    assert_parse('<table class="striped"><td align="justify">foo</td></table>', '[table][td align="justify"]foo[/td][/table]')
    assert_parse('<table class="striped"><td>foo</td></table>',                 '[table][td align="blah"]foo[/td][/table]')

    assert_parse('<table class="striped"><th align="left">foo</th></table>', '[table][th align="left"]foo[/th][/table]')
    assert_parse('<table class="striped"><tr align="left"><td>foo</td></tr></table>', '[table][tr align="left"][td]foo[/td][/tr][/table]')
    assert_parse('<table class="striped"><tbody align="left"><td>foo</td></tbody></table>', '[table][tbody align="left"][td]foo[/td][/tbody][/table]')
    assert_parse('<table class="striped"><thead align="left"><td>foo</td></thead></table>', '[table][thead align="left"][td]foo[/td][/thead][/table]')

    assert_parse('<table class="striped"><colgroup></colgroup><td>foo</td></table>', '[table][colgroup align="left"][/colgroup][td]foo[/td][/table]')
    assert_parse('<table class="striped"><colgroup></colgroup><td>foo</td></table>', '[table][colgroup span="1"][/colgroup][td]foo[/td][/table]')

    assert_parse('<table class="striped"><colgroup><col align="left"><col align="right" span="2"></colgroup><td>one</td><td>two</td><td>three</td></table>', '[table][colgroup][col align="left"][col align="right" span="2"][/colgroup][td]one[/td][td]two[/td][td]three[/td][/table]')

    assert_parse('<table class="striped"><tr><th>foo</th></tr><tr><td>bar</td></tr></table>', "[table][tr][th]foo\n [/th][/tr][tr][td]bar\n [/td][/tr][/table]")
  end

  def test_unclosed_tables
    assert_parse('<table class="striped"><th>foo</th></table>', "[table][th]foo")
    assert_parse('<table class="striped"><td>foo</td></table>', "[table][td]foo")
    assert_parse('<table class="striped"><tr><td>foo</td></tr></table>', "[table][tr][td]foo")
    assert_parse('<table class="striped"><thead><td>foo</td></thead></table>', "[table][thead][td]foo") # XXX wrong
    assert_parse('<table class="striped"><tbody><td>foo</td></tbody></table>', "[table][tbody][td]foo") # XXX wrong
    assert_parse('<table class="striped"><colgroup><td>foo</td></colgroup></table>', "[table][colgroup][td]foo") # XXX wrong
    assert_parse('<table class="striped"><colgroup><col><td>foo</td></colgroup></table>', "[table][colgroup][col][td]foo") # XXX wrong
  end

  def test_forum_links
    assert_parse('<p><a class="dtext-link dtext-id-link dtext-forum-topic-id-link" href="/forums/topics/1234?page=4">topic #1234 (page 4)</a></p>', "topic #1234/p4")
    assert_parse('<p><a class="dtext-link dtext-forum-topic-link" href="/forums/topics/1234">Topic: Topic Name</a></p>', "[topic=1234]Topic Name[/topic]")
    assert_parse('<p><a class="dtext-link dtext-forum-topic-link" href="/forums/topics/1234">Topic: Topic Name</a></p>', "[topic=1234]Topic Name")
  end

  def test_id_links
    assert_parse_id_link("dtext-post-id-link", "/posts/1234", "post #1234")
    assert_parse_id_link("dtext-post-changes-for-id-link", "/posts/versions?search[post_id]=1234", "post changes #1234")
    assert_parse_id_link("dtext-post-changes-for-id-version-link", "/posts/versions?search[post_id]=1234&search[version]=4321", "post changes #1234:4321", text: "post changes #1234")
    assert_parse_id_link("dtext-post-flag-id-link", "/posts/flags/1234", "flag #1234")
    assert_parse_id_link("dtext-note-id-link", "/notes/1234", "note #1234")
    assert_parse_id_link("dtext-forum-post-id-link", "/forums/posts/1234", "forum #1234")
    assert_parse_id_link("dtext-forum-topic-id-link", "/forums/topics/1234", "topic #1234")
    assert_parse_id_link("dtext-forum-category-id-link", "/forums/categories/1234", "category #1234")
    assert_parse_id_link("dtext-comment-id-link", "/comments/1234", "comment #1234")
    assert_parse_id_link("dtext-pool-id-link", "/pools/1234", "pool #1234")
    assert_parse_id_link("dtext-user-id-link", "/users/1234", "user #1234")
    assert_parse_id_link("dtext-artist-id-link", "/artists/1234", "artist #1234")
    assert_parse_id_link("dtext-ban-id-link", "/bans/1234", "ban #1234")
    assert_parse_id_link("dtext-tag-alias-id-link", "/tags/aliases/1234", "alias #1234")
    assert_parse_id_link("dtext-tag-implication-id-link", "/tags/implications/1234", "implication #1234")
    assert_parse_id_link("dtext-mod-action-id-link", "/mod_actions/1234", "mod action #1234")
    assert_parse_id_link("dtext-user-feedback-id-link", "/users/feedbacks/1234", "record #1234")
    assert_parse_id_link("dtext-wiki-page-id-link", "/wiki_pages/1234", "wiki #1234")
    assert_parse_id_link("dtext-dmail-id-link", "/dmails/1234", "dmail #1234")
    assert_parse_id_link("dtext-set-id-link", "/post_sets/1234", "set #1234")
    assert_parse_id_link("dtext-ticket-id-link", "/tickets/1234", "ticket #1234")
    assert_parse_id_link("dtext-avoid-posting-id-link", "/avoid_postings/1234", "avoid posting #1234")
    assert_parse_id_link("dtext-takedown-id-link", "/takedowns/1234", "takedown #1234")

    assert_parse_id_link("dtext-github-id-link", "https://github.com/FemboyFans/FemboyFans/issues/1234", "issue #1234")
    assert_parse_id_link("dtext-github-pull-id-link", "https://github.com/FemboyFans/FemboyFans/pull/1234", "pull #1234")
    assert_parse_id_link("dtext-github-commit-id-link", "https://github.com/FemboyFans/FemboyFans/commit/1234", "commit #1234")

    assert_parse('<p>(R-18指定注意)→<a class="dtext-link dtext-id-link dtext-post-id-link" href="/posts/2053744">post #2053744</a></p>', '(R-18指定注意)→post #2053744')

    assert_parse("<p>shitpost #24</p>", "shitpost #24")
    assert_parse("<p>Spiderman/Deadpool #69</p>", "Spiderman/Deadpool #69")
    assert_parse("<p>◼️船乗りの恋人1pixiv #64368055の続きです。</p>", "◼️船乗りの恋人1pixiv #64368055の続きです。")
  end

  def test_dmail_key_id_link
    assert_parse(%{<p><a class="dtext-link dtext-id-link dtext-dmail-id-link" href="/dmails/1234?key=abc%3D%3D--DEF123">dmail #1234</a></p>}, "dmail #1234/abc==--DEF123")
    assert_parse(%{<p><a class="dtext-link dtext-id-link dtext-dmail-id-link" href="http://danbooru.donmai.us/dmails/1234?key=abc%3D%3D--DEF123">dmail #1234</a></p>}, "dmail #1234/abc==--DEF123", base_url: "http://danbooru.donmai.us")
  end

  def test_boundary_exploit
    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="mack" href="/users?name=mack">@mack</a>&lt;</p>', "@mack<")
  end

  def test_section
    assert_parse("<details><summary></summary><div><p>hello world</p></div></details>", "[section]hello world[/section]")
    assert_parse("<details><summary></summary><div><p>hello world</p></div></details>", "<section>hello world</section>")
    assert_parse("<details><summary></summary><div><p>hello world</p></div></details>", "<section>hello world[/section]")
    assert_parse("<details><summary></summary><div><p>hello world</p></div></details>", "[section]hello world</section>")

    assert_parse("<p>inline [section]blah blah[/section]</p>", "inline [section]blah blah[/section]")
    assert_parse("<p>inline <em>foo [section]blah blah[/section]</em></p>", "inline [i]foo [section]blah blah[/section]")
    assert_parse('<p>inline <span class="spoiler">foo [section]blah blah[/section]</span></p>', "inline [spoiler]foo [section]blah blah[/section]")

    assert_parse("<p>inline <em>foo</em></p><details><summary></summary><div><p>blah blah</p></div></details>", "inline [i]foo\n\n[section]blah blah[/section]")
    assert_parse('<p>inline <span class="spoiler">foo</span></p><details><summary></summary><div><p>blah blah</p></div></details>', "inline [spoiler]foo\n\n[section]blah blah[/section]")

    assert_parse('<details><summary></summary><div><p>test</p></div></details>', "[section]\ntest\n[/section] ")
    assert_parse('<details><summary></summary><div><p>test</p></div></details><p>blah</p>', "[section]\ntest\n[/section] blah")
    assert_parse('<details><summary></summary><div><p>test</p></div></details><p>blah</p>', "[section]\ntest\n[/section] \nblah")
    assert_parse('<details><summary></summary><div><p>test</p></div></details><p>blah</p>', "[section]\ntest\n[/section]\nblah")
    assert_parse('<details><summary></summary><div><p>test</p></div></details><p> blah</p>', "[section]\ntest\n[/section]\n blah") # XXX should ignore space

    assert_parse("<p>[/section]</p>", "[/section]")
    assert_parse("<p>foo [/section] bar</p>", "foo [/section] bar")
    assert_parse('<p>test<br>[/section] blah</p>', "test\n[/section] blah")
    assert_parse('<p>test<br>[/section]</p><ul><li>blah</li></ul>', "test\n[/section]\n* blah")

    assert_parse('<details><summary></summary><div><p>test</p></div></details><h4>See also</h4>', "[section]\ntest\n[/section]\nh4. See also")
    assert_parse('<details><summary></summary><div><p>test</p></div></details><div class="spoiler"><p>blah</p></div>', "[section]\ntest\n[/section]\n[spoiler]blah[/spoiler]")

    assert_parse("<details><summary></summary><div><p>foo</p></div></details>", "[section]\nfoo\n [/section]")
    assert_parse("<details><summary></summary><div><p>foo</p></div></details>", "[section]\nfoo\n\n [/section]")
    assert_parse("<details><summary></summary><div><ul><li>foo</li></ul></div></details>", "[section]\n* foo\n [/section]")
  end

  def test_aliased_section
    assert_parse("<details><summary>hello</summary><div><p>blah blah</p></div></details>", "[section=hello]blah blah[/section]")
    assert_parse("<details><summary>hello</summary><div><p>blah blah</p></div></details>", "[section hello]blah blah[/section]")
    assert_parse("<details><summary>hello</summary><div><p>blah blah</p></div></details>", "[section = hello]blah blah[/section]")
    assert_parse("<details><summary>hello</summary><div><p>blah blah</p></div></details>", "[section= hello]blah blah[/section]")
    assert_parse("<details><summary>hello</summary><div><p>blah blah</p></div></details>", "[section =hello]blah blah[/section]")

    assert_parse("<details><summary>hello</summary><div><p>blah blah</p></div></details>", "<section=hello>blah blah</section>")
    assert_parse("<details><summary>ab]cd</summary><div><p>blah blah</p></div></details>", "<section=ab]cd>blah blah</section>")
    assert_parse("<details><summary>ab</summary><div><p>cd&gt;blah blah</p></div></details>", "<section=ab>cd>blah blah</section>")

    assert_parse("<details><summary></summary><div><p>blah blah</p></div></details>", "[section=]blah blah[/section]")
    assert_parse("<details><summary></summary><div><p>blah blah</p></div></details>", "<section=>blah blah</section>")
    assert_parse("<details><summary></summary><div><p>blah blah</p></div></details>", "[section ]blah blah[/section]")
    assert_parse("<details><summary></summary><div><p>blah blah</p></div></details>", "[section= ]blah blah[/section]")

    assert_parse("<p>[sectionhello]blah blah[/section]</p>", "[sectionhello]blah blah[/section]")
    assert_parse("<p>[section <br>title]blah blah[/section]</p>", "[section \ntitle]blah blah[/section]")

    assert_parse("<p>inline [section=hello]blah[/section]</p>", "inline [section=hello]blah[/section]")

    assert_parse("<p>inline</p><details><summary>hello</summary><div><p>blah</p></div></details><p>blah</p>", "inline\n[section=hello]blah[/section]\nblah")
    assert_parse("<ul><li>list</li></ul><details><summary>hello</summary><div><p>blah</p></div></details>", "* list\n[section=hello]blah[/section]")

    assert_parse("<ul><li>list [section=hello]blah[/section]</li></ul>", "* list [section=hello]blah[/section]")
    assert_parse("<h1>foo [section=hello]blah[/section]</h1>", "h1. foo [section=hello]blah[/section]")
    assert_parse("<h1>foo</h1><details><summary>hello</summary><div><p>blah</p></div></details>", "h1. foo\n[section=hello]blah[/section]")

    assert_parse("<p>inline <em>foo [section=title]blah blah[/section]</em></p>", "inline [i]foo [section=title]blah blah[/section]")
    assert_parse('<p>inline <span class="spoiler">foo [section=title]blah blah[/section]</span></p>', "inline [spoiler]foo [section=title]blah blah[/section]")
  end

  def test_section_expanded
    assert_parse("<details open><summary></summary><div><p>hello world</p></div></details>", "[section,expanded]hello world[/section]")
    assert_parse("<details open><summary></summary><div><p>hello world</p></div></details>", "<section,expanded>hello world</section>")
    assert_parse("<details open><summary></summary><div><p>hello world</p></div></details>", "<section,expanded>hello world[/section]")
    assert_parse("<details open><summary></summary><div><p>hello world</p></div></details>", "[section,expanded]hello world</section>")

    assert_parse("<p>inline [section]blah blah[/section]</p>", "inline [section]blah blah[/section]")
    assert_parse("<p>inline <em>foo [section]blah blah[/section]</em></p>", "inline [i]foo [section]blah blah[/section]")
    assert_parse('<p>inline <span class="spoiler">foo [section]blah blah[/section]</span></p>', "inline [spoiler]foo [section]blah blah[/section]")

    assert_parse("<p>inline <em>foo</em></p><details open><summary></summary><div><p>blah blah</p></div></details>", "inline [i]foo\n\n[section,expanded]blah blah[/section]")
    assert_parse('<p>inline <span class="spoiler">foo</span></p><details open><summary></summary><div><p>blah blah</p></div></details>', "inline [spoiler]foo\n\n[section,expanded]blah blah[/section]")

    assert_parse('<details open><summary></summary><div><p>test</p></div></details>', "[section,expanded]\ntest\n[/section] ")
    assert_parse('<details open><summary></summary><div><p>test</p></div></details><p>blah</p>', "[section,expanded]\ntest\n[/section] blah")
    assert_parse('<details open><summary></summary><div><p>test</p></div></details><p>blah</p>', "[section,expanded]\ntest\n[/section] \nblah")
    assert_parse('<details open><summary></summary><div><p>test</p></div></details><p>blah</p>', "[section,expanded]\ntest\n[/section]\nblah")
    assert_parse('<details open><summary></summary><div><p>test</p></div></details><p> blah</p>', "[section,expanded]\ntest\n[/section]\n blah") # XXX should ignore space

    assert_parse("<p>[/section]</p>", "[/section]")
    assert_parse("<p>foo [/section] bar</p>", "foo [/section] bar")
    assert_parse('<p>test<br>[/section] blah</p>', "test\n[/section] blah")
    assert_parse('<p>test<br>[/section]</p><ul><li>blah</li></ul>', "test\n[/section]\n* blah")

    assert_parse('<details open><summary></summary><div><p>test</p></div></details><h4>See also</h4>', "[section,expanded]\ntest\n[/section]\nh4. See also")
    assert_parse('<details open><summary></summary><div><p>test</p></div></details><div class="spoiler"><p>blah</p></div>', "[section,expanded]\ntest\n[/section]\n[spoiler]blah[/spoiler]")

    assert_parse("<details open><summary></summary><div><p>foo</p></div></details>", "[section,expanded]\nfoo\n [/section]")
    assert_parse("<details open><summary></summary><div><p>foo</p></div></details>", "[section,expanded]\nfoo\n\n [/section]")
    assert_parse("<details open><summary></summary><div><ul><li>foo</li></ul></div></details>", "[section,expanded]\n* foo\n [/section]")
  end

  def test_aliased_section_expanded
    assert_parse("<details open><summary>hello</summary><div><p>blah blah</p></div></details>", "[section,expanded=hello]blah blah[/section]")
    assert_parse("<details open><summary>hello</summary><div><p>blah blah</p></div></details>", "[section,expanded hello]blah blah[/section]")
    assert_parse("<details open><summary>hello</summary><div><p>blah blah</p></div></details>", "[section,expanded = hello]blah blah[/section]")
    assert_parse("<details open><summary>hello</summary><div><p>blah blah</p></div></details>", "[section,expanded= hello]blah blah[/section]")
    assert_parse("<details open><summary>hello</summary><div><p>blah blah</p></div></details>", "[section,expanded =hello]blah blah[/section]")

    assert_parse("<details open><summary>hello</summary><div><p>blah blah</p></div></details>", "<section,expanded=hello>blah blah</section>")
    assert_parse("<details open><summary>ab]cd</summary><div><p>blah blah</p></div></details>", "<section,expanded=ab]cd>blah blah</section>")
    assert_parse("<details open><summary>ab</summary><div><p>cd&gt;blah blah</p></div></details>", "<section,expanded=ab>cd>blah blah</section>")

    assert_parse("<details open><summary></summary><div><p>blah blah</p></div></details>", "[section,expanded=]blah blah[/section]")
    assert_parse("<details open><summary></summary><div><p>blah blah</p></div></details>", "<section,expanded=>blah blah</section>")
    assert_parse("<details open><summary></summary><div><p>blah blah</p></div></details>", "[section,expanded ]blah blah[/section]")
    assert_parse("<details open><summary></summary><div><p>blah blah</p></div></details>", "[section,expanded= ]blah blah[/section]")

    assert_parse("<p>[sectionhello]blah blah[/section]</p>", "[sectionhello]blah blah[/section]")
    assert_parse("<p>[section <br>title]blah blah[/section]</p>", "[section \ntitle]blah blah[/section]")

    assert_parse("<p>inline [section=hello]blah[/section]</p>", "inline [section=hello]blah[/section]")

    assert_parse("<p>inline</p><details open><summary>hello</summary><div><p>blah</p></div></details><p>blah</p>", "inline\n[section,expanded=hello]blah[/section]\nblah")
    assert_parse("<ul><li>list</li></ul><details open><summary>hello</summary><div><p>blah</p></div></details>", "* list\n[section,expanded=hello]blah[/section]")

    assert_parse("<ul><li>list [section=hello]blah[/section]</li></ul>", "* list [section=hello]blah[/section]")
    assert_parse("<h1>foo [section=hello]blah[/section]</h1>", "h1. foo [section=hello]blah[/section]")
    assert_parse("<h1>foo</h1><details open><summary>hello</summary><div><p>blah</p></div></details>", "h1. foo\n[section,expanded=hello]blah[/section]")

    assert_parse("<p>inline <em>foo [section=title]blah blah[/section]</em></p>", "inline [i]foo [section=title]blah blah[/section]")
    assert_parse('<p>inline <span class="spoiler">foo [section=title]blah blah[/section]</span></p>', "inline [spoiler]foo [section=title]blah blah[/section]")
  end

  def test_section_with_nested_code
    assert_parse("<details><summary></summary><div><pre>hello</pre></div></details>", "[section]\n[code]\nhello\n[/code]\n[/section]")
  end

  def test_section_with_nested_list
    assert_parse("<details><summary></summary><div><ul><li>a</li><li>b</li></ul></div></details><p>c</p>", "[section]\n* a\n* b\n[/section]\nc")
  end

  def test_hr
    assert_parse("<hr>", "[hr]")
    assert_parse("<hr>", "[HR]")
    assert_parse("<hr>", "<hr>")

    assert_parse("<hr>", " [hr]")
    assert_parse("<hr>", "[hr] ")
    assert_parse("<hr>", " [hr] ")
    assert_parse("<hr>", "\n\n [hr] \n\n")

    assert_parse("<hr><hr><hr>", "[hr]\n\n[hr]\n\n[hr]")
    assert_parse("<hr><hr><hr>", "[hr]\n[hr]\n[hr]")

    assert_parse("<p>foo</p><hr>", "foo\n\n[hr]")
    assert_parse("<hr><p>foo</p>", "[hr]\n\nfoo")

    assert_parse("<p>foo</p><hr>", "foo\n[hr]")
    assert_parse("<hr><p>foo</p>", "[hr]\nfoo")

    assert_parse("<p>x[hr]</p>", "x[hr]")
    assert_parse("<p>[hr]x</p>", "[hr]x")
    assert_parse("<p>foo [hr] bar</p>", "foo [hr] bar")
    assert_parse("<p>[hr][hr]</p>", "[hr][hr]")

    assert_parse("<h1>[hr]</h1>", "h1. [hr]")
    assert_parse("<ul><li>[hr]</li></ul>", "* [hr]")

    assert_parse("<blockquote><hr></blockquote>", "[quote]\n[hr]\n[/quote]")
    assert_parse('<div class="spoiler"><hr></div>', "[spoiler]\n[hr]\n[/spoiler]")
    assert_parse('<p class="dtext-note"><hr></p>', "[note]\n[hr]\n[/note]")
    assert_parse("<details><summary></summary><div><hr></div></details>", "[section]\n[hr]\n[/section]")
    assert_parse("<pre>[hr]</pre>", "[code]\n[hr]\n[/code]")
    assert_parse("<p>[hr]</p>", "[nodtext]\n[hr]\n[/nodtext]")
    assert_parse('<table class="striped"></table>', "[table]\n[hr]\n[/table]")

    assert_parse("<h1>foo</h1><hr>", "h1. foo\n[hr]")
    assert_parse("<ul><li>foo</li></ul><hr>", "* foo\n[hr]")

    #assert_parse("<blockquote><hr></blockquote>", "[quote][hr][/quote]") # XXX should this work?
    #assert_parse('<div class="spoiler"><hr></div>', "[spoiler][hr][/spoiler]") # XXX should this work?
    #assert_parse("<details><summary></summary><hr></details>", "[section][hr][/section]") # XXX should this work?

    assert_parse("<blockquote><hr></blockquote>", "[quote]\n[hr]\n[/quote]")
    assert_parse('<div class="spoiler"><hr></div>', "[spoiler]\n[hr]\n[/spoiler]")
    assert_parse("<details><summary></summary><div><hr></div></details>", "[section]\n[hr]\n[/section]")

    assert_parse('<p>inline <strong></strong></p><hr><p>[/b]</p>', "inline [b]\n[hr]\n[/b]")
    assert_parse('<p>inline <span class="dtext-note"></span></p><hr><p>[/note]</p>', "inline [note]\n[hr]\n[/note]")

    assert_parse('<p>inline <span class="spoiler"></span></p><hr><p>[/spoiler]</p>', "inline [spoiler]\n[hr]\n[/spoiler]")

    assert_parse('<p>foo <strong>bar</strong></p><hr>', "foo [b]bar\n[hr]")

    #assert_parse('<p class="dtext-note"><hr></p>', "[note][hr][/note]") # XXX shouldn't work
  end

  def test_br
    assert_parse("<p>foo<br>bar</p>", "foo[br]bar")
    assert_parse("<p>foo<br>bar</p>", "foo[BR]bar")
    assert_parse("<p>foo<br>bar</p>", "foo<br>bar")
    assert_parse("<p>foo<br>bar</p>", "foo<BR>bar")

    assert_parse("<ul><li>foo<br>bar</li></ul>", "* foo<br>bar")
    assert_parse('<table class="striped"><tr><td>foo<br>bar</td></tr></table>', "[table][tr][td]foo[br]bar[/td][/tr][/table]")

    assert_parse("<h4>foo&lt;br&gt;bar</h4>", "h4. foo<br>bar")
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=foo">bar&lt;br&gt;baz</a></p>', "[[foo|bar<br>baz]]")
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="http://example.com">foo&lt;br&gt;bar</a></p>', '"foo<br>bar":http://example.com')

    assert_parse("<p>foo <br></p><p>bar</p>", "foo [br]\n\nbar")
    assert_parse("<p>foo<br><br><br></p><p>bar</p>", "foo\n[br][br]\n\nbar")
    assert_parse("<p>foo</p><p><br></p><p>bar</p>", "foo\n\n[br]\n\nbar")
    assert_parse("<p>foo</p><p><br><br></p><p>bar</p>", "foo\n\n[br][br]\n\nbar")
  end

  def test_inline_mode
    assert_equal("hello", parse_inline("hello").strip)
  end

  def test_old_asterisks
    assert_parse("<p>hello *world* neutral</p>", "hello *world* neutral")
  end

  def test_utf8_mentions
    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="葉月" href="/users?name=%E8%91%89%E6%9C%88">@葉月</a></p>', "@葉月")
    assert_parse('<p>Hello <a class="dtext-link dtext-user-mention-link" data-user-name="葉月" href="/users?name=%E8%91%89%E6%9C%88">@葉月</a> and <a class="dtext-link dtext-user-mention-link" data-user-name="Alice" href="/users?name=Alice">@Alice</a></p>', "Hello @葉月 and @Alice")
    assert_parse('<p>Should not parse 葉月@葉月</p>', "Should not parse 葉月@葉月")
  end

  def test_mention_boundaries
    assert_parse('<p>「hi <a class="dtext-link dtext-user-mention-link" data-user-name="葉月" href="/users?name=%E8%91%89%E6%9C%88">@葉月</a>」</p>', "「hi @葉月」")
  end

  def test_delimited_mentions
    assert_parse('<p>(blah <a class="dtext-link dtext-user-mention-link" data-user-name="evazion" href="/users?name=evazion">@evazion</a>).</p>', "(blah <@evazion>).")
    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="葉月" href="/users?name=%E8%91%89%E6%9C%88">@葉月</a></p>', "<@葉月>")

    # assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="nwf_renim" href="/users?name=nwf_renim">@NWF Renim</a></p>', "<@NWF Renim>")
    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="NWF Renim" href="/users?name=NWF%20Renim">@NWF Renim</a></p>', "<@NWF Renim>") # XXX should normalize to nwf_renim for href

    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="_evazion" href="/users?name=_evazion">@_evazion</a></p>', "<@_evazion>")
    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="evazion_" href="/users?name=evazion_">@evazion_</a></p>', "<@evazion_>")
    assert_parse('<p><a class="dtext-link dtext-user-mention-link" data-user-name="evazion" href="/users?name=evazion">@evazion</a>blah&gt;</p>', "<@evazion>blah>")

    assert_parse('<p>&lt;@ evazion&gt;</p>', "<@ evazion>")
    assert_parse('<p>&lt;@<br>evazion&gt;</p>', "<@\nevazion>")
    assert_parse('<p>&lt;@eva<br>zion&gt;</p>', "<@eva\nzion>")
  end

  def test_utf8_links
    assert_parse('<p><a class="dtext-link" href="/posts?tags=approver:葉月">7893</a></p>', '"7893":/posts?tags=approver:葉月')
    assert_parse('<p><a class="dtext-link" href="/posts?tags=approver:葉月">7893</a></p>', '"7893":[/posts?tags=approver:葉月]')
    assert_parse('<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="http://danbooru.donmai.us/posts?tags=approver:葉月">http://danbooru.donmai.us/posts?tags=approver:葉月</a></p>', 'http://danbooru.donmai.us/posts?tags=approver:葉月')
    assert_parse('<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=full_metal_panic%21_%CE%A3">Full Metal Panic! Σ</a></p>', '[[Full Metal Panic! Σ]]')
    assert_parse(%{<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=%C2%97">\u0097</a></p>}, "[[\u0097]]")
    assert_parse(%{<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="https://www.example.com/\u0097">\u0097</a></p>}, %{"\u0097":https://www.example.com/\u0097})
  end

  def test_delimited_links
    dtext = '(blah <https://en.wikipedia.org/wiki/Orange_(fruit)>).'
    html = '<p>(blah <a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://en.wikipedia.org/wiki/Orange_(fruit)">https://en.wikipedia.org/wiki/Orange_(fruit)</a>).</p>'
    assert_parse(html, dtext)
  end

  def test_nodtext
    assert_parse('<p>[b]not bold[/b]</p><p> <strong>bold</strong></p>', "[nodtext][b]not bold[/b][/nodtext] [b]bold[/b]")
    assert_parse('<p>[b]not bold[/b]</p><p><strong>hello</strong></p>', "[nodtext][b]not bold[/b][/nodtext]\n\n[b]hello[/b]")
    assert_parse('<p> [b]not bold[/b]</p>', " [nodtext][b]not bold[/b][/nodtext]")
    assert_parse('<p>[b]not bold</p>', "[nodtext][b]not bold")
    assert_parse('<h1>[b]not bold</h1>', "h1. [nodtext][b]not bold")
    assert_parse('<ul><li>[b]not bold</li></ul>', "* [nodtext][b]not bold")
    assert_parse('<div class="spoiler"><p>[b]not bold</p></div>', "[spoiler][nodtext][b]not bold")
    assert_parse('<p class="dtext-note">[b]not bold</p>', "[note][nodtext][b]not bold")
    assert_parse('<blockquote><p>[b]not bold</p></blockquote>', "[quote][nodtext][b]not bold")
    assert_parse('<p>foo  bar</p>', "foo [nodtext] bar")
    assert_parse('<p>foo bar</p>', "foo [nodtext]bar[/nodtext]")
    assert_parse('<p></p>', "[nodtext]")
    assert_parse('<p></p>', "[nodtext][/nodtext]")
    assert_parse('<p>[/nodtext]</p>', "[/nodtext]")

    assert_parse("<p>foo  bar </p>", "foo [nodtext] bar [/nodtext]")
    assert_parse("<p>foo bar</p>", "foo [nodtext]\nbar\n[/nodtext]")
    assert_parse("<p>foo bar </p>", "foo [nodtext] \nbar \n[/nodtext]")
    assert_parse("<p> bar </p>", "[nodtext] bar [/nodtext]")
    assert_parse("<p>bar</p>", "[nodtext]\nbar\n[/nodtext]")
    assert_parse("<p>bar </p>", "[nodtext] \nbar \n[/nodtext]")

    assert_parse('<p>inline</p><p>[/i]</p>', "inline\n[nodtext]\n[/i]\n[/nodtext]")
    assert_parse('<p>inline</p><p>[/i]</p>', "inline\n[nodtext][/i][/nodtext]")
    assert_parse("<p><em>inline</em></p><p>[/i]</p>", "[i]inline\n[nodtext]\n[/i]\n[/nodtext]")
    assert_parse('<p><em>inline</em></p><p>[/i]</p>', "[i]inline\n[nodtext][/i][/nodtext]")

    assert_parse("<p>inline</p><p>[/i]</p>", "inline\n\n[nodtext]\n[/i]\n[/nodtext]")
    assert_parse('<p>inline</p><p>[/i]</p>', "inline\n\n[nodtext][/i][/nodtext]")
    assert_parse("<p><em>inline</em></p><p>[/i]</p>", "[i]inline\n\n[nodtext]\n[/i]\n[/nodtext]")
    assert_parse('<p><em>inline</em></p><p>[/i]</p>', "[i]inline\n\n[nodtext][/i][/nodtext]")

    assert_parse('', "[nodtext]", inline: true)
    assert_parse('', "[nodtext][/nodtext]", inline: true)
  end

  def test_stray_closing_tags
    assert_parse('<p>inline &lt;/b&gt;</p>', 'inline </b>')
    assert_parse('<p>inline &lt;/i&gt;</p>', 'inline </i>')
    assert_parse('<p>inline &lt;/u&gt;</p>', 'inline </u>')
    assert_parse('<p>inline &lt;/s&gt;</p>', 'inline </s>')
    assert_parse('<p>inline &lt;/code&gt;</p>', 'inline </code>')
    assert_parse('<p>inline &lt;/nodtext&gt;</p>', 'inline </nodtext>')
    assert_parse('<p>inline &lt;/table&gt;</p>', 'inline </table>')
    assert_parse('<p>inline &lt;/thead&gt;</p>', 'inline </thead>')
    assert_parse('<p>inline &lt;/tbody&gt;</p>', 'inline </tbody>')
    assert_parse('<p>inline &lt;/tr&gt;</p>', 'inline </tr>')
    assert_parse('<p>inline &lt;/th&gt;</p>', 'inline </th>')
    assert_parse('<p>inline &lt;/td&gt;</p>', 'inline </td>')

    assert_parse('<p>inline &lt;/note&gt;</p>', 'inline </note>')
    assert_parse('<p>inline &lt;/spoiler&gt;</p>', 'inline </spoiler>')
    assert_parse('<p>inline &lt;/section&gt;</p>', 'inline </section>')
    assert_parse('<p>inline &lt;/quote&gt;</p>', 'inline </quote>')

    assert_parse('<p>&lt;/spoiler&gt;</p>', '</spoiler>')
    assert_parse('<p>&lt;/section&gt;</p>', '</section>')
    assert_parse('<p>&lt;/quote&gt;</p>', '</quote>')
    assert_parse('<p>&lt;/note&gt;</p>', '</note>')
    assert_parse('<p>&lt;/spoiler&gt;</p>', '</spoiler>')
    assert_parse('<p>&lt;/section&gt;</p>', '</section>')
    assert_parse('<p>&lt;/quote&gt;</p>', '</quote>')

    assert_parse('<p>&lt;/b&gt;</p>', '</b>')
    assert_parse('<p>&lt;/i&gt;</p>', '</i>')
    assert_parse('<p>&lt;/u&gt;</p>', '</u>')
    assert_parse('<p>&lt;/s&gt;</p>', '</s>')
    assert_parse('<p>&lt;/code&gt;</p>', '</code>')
    assert_parse('<p>&lt;/nodtext&gt;</p>', '</nodtext>')
    assert_parse('<p>&lt;/table&gt;</p>', '</table>')
    assert_parse('<p>&lt;/thead&gt;</p>', '</thead>')
    assert_parse('<p>&lt;/tbody&gt;</p>', '</tbody>')
    assert_parse('<p>&lt;/tr&gt;</p>', '</tr>')
    assert_parse('<p>&lt;/th&gt;</p>', '</th>')
    assert_parse('<p>&lt;/td&gt;</p>', '</td>')
  end

  def test_mismatched_tags
    assert_parse('<p>inline <strong>foo</strong></p>', 'inline [b]foo[/i]')
    assert_parse('<p>inline <strong><em>foo</em></strong></p>', 'inline [b][i]foo[/b][/i]')
    assert_parse('<p>inline <span class="spoiler"><em>foo</em></span></p>', 'inline [spoiler][i]foo[/spoiler][/i]')

    # assert_parse('<div class="spoiler"><blockquote><p>foo</p></blockquote></div>', '[spoiler]\n[quote]\nfoo\n[/spoiler][/quote]')
  end

  def test_null_bytes
    assert_raises(DText::Error) { parse_dtext("foo\0bar") }
  end

  def test_encodings
    assert_parse("<p>foo</p>", "foo".dup.force_encoding("US-ASCII"))
    assert_parse("<p>foo</p>", "foo".dup.force_encoding("UTF-8"))
    assert_raises(DText::Error) { parse_dtext("foo".dup.force_encoding("ASCII-8BIT")) }
    assert_raises(DText::Error) { parse_dtext("\xFF".dup.force_encoding("US-ASCII")) }
    assert_raises(DText::Error) { parse_dtext("\xFF".dup.force_encoding("UTF-8")) }
  end

  def test_wiki_link_xss
    assert_raises(DText::Error) do
      parse_dtext("[[\xFA<script \xFA>alert(42); //\xFA</script \xFA>]]")
    end
  end

  def test_mention_xss
    assert_raises(DText::Error) do
      parse_dtext("@user\xF4<b>xss\xFA</b>")
    end
  end

  def test_url_xss
    assert_raises(DText::Error) do
      parse_dtext(%("url":/page\xF4">x\xFA<b>xss\xFA</b>))
    end
  end
end
