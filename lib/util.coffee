


exports.status404Line = 'HTTP/1.1 404 Not Found\r\n'

SPACE = 0x20   # ' '
COLON = 0x3a   # 58, :
NEWLINE = 0x0a # \n
ENTER = 0x0d   # \r

# 典型的http头
# GET /work1 HTTP/1.1
# Host: www.work1.com:1723
# Connection: keep-alive
# Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
# User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_3) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.57 Safari/537.17
# Accept-Encoding: gzip,deflate,sdch
# Accept-Language: zh-CN,zh;q=0.8
# Accept-Charset: UTF-8,*;q=0.5
# 
exports.getHead = (data) ->
  start = 0
  lineStart = 0
  lineCount = 0
  header = {}
  firstLineCount = 0
  firstLineStart = 0
  for value, i in data
    # 换行 '\r\n'
    if value is  ENTER and data[i + 1] is NEWLINE
      if data[i + 2] is  ENTER and data[i + 3] is NEWLINE
        # \r\n\r\n Host header not found
        return
      lineCount++
      lineStart = i + 2
    else
      #GET / HTTP/1.1
      if lineCount is 0
        if value is SPACE
          if (++firstLineCount) is 2
            header.url = data.toString('ascii', firstLineStart + 1, i)
          firstLineStart = i
      #Host: www.work1.com:1723
      #Cache-Control: max-age=0
      else
        if value is COLON and data[i + 1] is SPACE
          key = data.toString('ascii', lineStart, i).toLowerCase();
          if key is 'host'
            for hk, hi in data[(i + 2)..]
              if hk is ENTER
                header[key] = data.toString('ascii', i + 2, i + 2 + hi).trim().toLowerCase();
                return header
          valueStart = i + 2


exports.checkHead = (data) ->
  lineCount = 0
  for value, i in data
    if value is  ENTER and data[i + 1] is NEWLINE
      lineCount++;
      return true if lineCount is 2
  return false

