/* eslint-env amd, browser, node */

(function (root, factory) {
  if (typeof define === 'function' && define.amd) {
    // AMD. Register as an anonymous module.
    define(factory);
  } else if (typeof module === 'object' && module.exports) {
    // Node. Does not work with strict CommonJS, but
    // only CommonJS-like environments that support module.exports,
    // like Node.
    module.exports = factory();
  } else {
    // Browser globals
    root.timeAgo = factory();
  }
}(this, function () {

  var timeFormats = [
    [45,       '几秒',           '几秒'   ], // 0 to 44 seconds
    [90,       '1 分钟',         '1 分钟' ], // 45 to 89 seconds
    [2700,     ' 分钟',          60      ], // 90 seconds to 44 minutes
    [5400,     '1 小时',         '1 小时' ], // 45 to 89 minutes
    [79200,    ' 小时',          3600    ], // 90 minutes to 21 hours
    [129600,   '1 天',           '1 天'  ], // 22 to 35 hours
    [2246400,  ' 天',            86400   ], // 36 hours to 25 days
    [3888000,  '1个月',          '1个月'  ], // 26 to 45 days
    [27648000, '个月',           2628288 ], // 45 to 319 days
    [47347200, '1 年',           '1 年'  ], // 320 to 547 days (1.5 years)
    [Infinity, ' 年',            31536000]  // 548 days+
  ];

  function round(value) {
    return Math.max(2, Math.floor(value));
  }

  function toUnixDate(time) {
    switch (typeof time) {
      case 'number':
        break;
      case 'string':
        time = +new Date(time);
        break;
      case 'undefined':
        time = +new Date();
        break;
      case 'object':
        if (time instanceof Date) {
          time = time.getTime();
          break;
        }
      default: // eslint-disable-line no-fallthrough
        throw new Error('An invalid type was used as a timeAgo function param.');
    }

    return time;
  }

  function timeAgo(time) {
    time = toUnixDate(time);

    var seconds = (+new Date() - time) / 1000;
    var listChoice = 1;

    if (seconds === 0) {
      // return 'just now';
      return '现在';
    }

    if (seconds < 0) {
      seconds = Math.abs(seconds);
      listChoice = 2;
    }

    // var prefixToken = listChoice === 2 ? 'in ' : '';
    // var postfixToken = listChoice === 1 ? ' ago' : '';
    var prefixToken = listChoice === 2 ? '' : '';
    var postfixToken = listChoice === 1 ? ' 之前' : ' 之后';
    var format;
    var i = 0;

    /* eslint-disable no-cond-assign */
    while (format = timeFormats[i++]) {
      if (seconds < format[0]) {
        if (typeof format[2] === 'string') {
          return prefixToken + format[listChoice] + postfixToken;
        } else {
          // return prefixToken + round(seconds / format[2]) + ' ' + format[1] + postfixToken;
          return prefixToken + round(seconds / format[2]) + format[1] + postfixToken;
        }
      }
    }
    /* eslint-enable no-cond-assign */
  }

  return timeAgo;
}));

