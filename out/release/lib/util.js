// Generated by CoffeeScript 1.10.0
var COLON, ENTER, NEWLINE, SPACE;

exports.status404Line = 'HTTP/1.1 404 Not Found\r\n';

SPACE = 0x20;

COLON = 0x3a;

NEWLINE = 0x0a;

ENTER = 0x0d;

exports.getHead = function(data) {
  var firstLineCount, firstLineStart, header, hi, hk, i, j, k, key, len, len1, lineCount, lineStart, ref, start, value, valueStart;
  start = 0;
  lineStart = 0;
  lineCount = 0;
  header = {};
  firstLineCount = 0;
  firstLineStart = 0;
  for (i = j = 0, len = data.length; j < len; i = ++j) {
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
            ref = data.slice(i + 2);
            for (hi = k = 0, len1 = ref.length; k < len1; hi = ++k) {
              hk = ref[hi];
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

exports.checkHead = function(data) {
  var i, j, len, lineCount, value;
  lineCount = 0;
  for (i = j = 0, len = data.length; j < len; i = ++j) {
    value = data[i];
    if (value === ENTER && data[i + 1] === NEWLINE) {
      lineCount++;
      if (lineCount === 2) {
        return true;
      }
    }
  }
  return false;
};

exports.upHeaderKey = function(key) {
  var arr, j, len, newArr;
  if (!key) {
    return;
  }
  arr = key.split('-');
  newArr = [];
  for (j = 0, len = arr.length; j < len; j++) {
    key = arr[j];
    newArr.push(key.substring(0, 1).toUpperCase() + key.substring(1));
  }
  return newArr.join('-');
};
