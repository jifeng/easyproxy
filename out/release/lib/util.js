// Generated by CoffeeScript 1.6.2
var COLON, ENTER, NEWLINE, SPACE;

exports.status404Line = 'HTTP/1.1 404 Not Found\r\n';

SPACE = 0x20;

COLON = 0x3a;

NEWLINE = 0x0a;

ENTER = 0x0d;

exports.getHead = function(data) {
  var firstLineCount, firstLineStart, header, hi, hk, i, key, lineCount, lineStart, start, value, valueStart, _i, _j, _len, _len1, _ref;

  start = 0;
  lineStart = 0;
  lineCount = 0;
  header = {};
  firstLineCount = 0;
  firstLineStart = 0;
  for (i = _i = 0, _len = data.length; _i < _len; i = ++_i) {
    value = data[i];
    if (value === ENTER && data[i + 1] === NEWLINE) {
      if (data[i + 2] === ENTER && data[i + 3] === NEWLINE) {
        return;
      }
      lineCount++;
      lineStart = i + 2;
    } else {
      if (lineCount === 0) {
        if (value === SPACE) {
          if ((++firstLineCount) === 2) {
            header.url = data.toString('ascii', firstLineStart + 1, i);
          }
          firstLineStart = i;
        }
      } else {
        if (value === COLON && data[i + 1] === SPACE) {
          key = data.toString('ascii', lineStart, i).toLowerCase();
          if (key === 'host') {
            _ref = data.slice(i + 2);
            for (hi = _j = 0, _len1 = _ref.length; _j < _len1; hi = ++_j) {
              hk = _ref[hi];
              if (hk === ENTER) {
                header[key] = data.toString('ascii', i + 2, i + 2 + hi).trim().toLowerCase();
                return header;
              }
            }
          }
          valueStart = i + 2;
        }
      }
    }
  }
};
