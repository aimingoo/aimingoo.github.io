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

        .main-nav a {
            color: #000;
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
        document.writeln(switcherObjects[authorName].toString().replace(/^[^\*]+\*+|\*+[^\*]+$/g, ''));
}