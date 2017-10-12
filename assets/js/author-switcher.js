var switcherObjects = {
    'aimingoo': function authorAimingooContext() {/*
        <style>
        body {
            background-image: url(/assets/img/background/201705a.jpg);
            background-repeat: no-repeat;
            background-position: top center;
            background-attachment: fixed;
            background-size: auto;
        }

        .site-wrapper {
            background: none;
        }

        .main-header {
            background: none;
            border-bottom: none;
        }

        .main-nav a {
            color: #FFF;
        }
        </style>
    */},
    'joyxhy': function authorJoyXHYContext() {/*
        <style>
        body {
            background-color: #f7faf2;
            background-image: url(/assets/img/background/201705j.jpg);
            background-repeat: no-repeat;
            background-position: top center;
            background-attachment: fixed;
            background-size: auto;
        }

        .site-wrapper {
            background: none;
        }

        .main-header {
            background: none;
            border-bottom: none;
        }

        .main-nav-title {
            padding: 23px 32px;
            background: rgba(255,255,255,.15);
        }

        .main-nav a {
            color: #f2dede;
        }

        .u-joyxhy a {
            color: #8e7588;
        }
       </style>
    */}
}

var authorName = [].slice.call(document.scripts)
    .filter(function(el) { return !!el.src.match(/author-switcher.js(\?.*){0,1}$/) })
    .map(function(el) { return el.getAttribute('author')})[0];

if (!authorName && (authorName = location.href.match(/\/author\/([^\/]+)\/?$/))) {
    authorName = authorName[1];
}


switcherObjects.default = switcherObjects.aimingoo;
switch (authorName && (authorName in switcherObjects)) {
    case false: authorName = 'aimingoo'; // or break only
    default:
        // custom styles
        document.writeln(switcherObjects[authorName].toString().replace(/^[^\*]+\*+|\*+[^\*]+$/g, ''));
        // custom header
        var all_nav_items = document.querySelector('header.main-header').querySelectorAll('div.nav.pull-right ul li');
        if (authorName == 'joyxhy') {
            var item = [].filter.call(all_nav_items, function(el) { return el.innerText=='首页'})[0];
            if (item) with (item.querySelector('A')) innerText="Aimingoo's Blog";
            var item = [].filter.call(all_nav_items, function(el) { return el.innerText=='历史'})[0];
            if (item) with (item.querySelector('A')) href=href.replace('archives-post', 'archives-post-joyxhy');
            var item = [].filter.call(all_nav_items, function(el) { return el.innerText=='关于'})[0];
            if (item) with (item.querySelector('A')) href=href.replace('about', 'about-joyxhy');
        }
}