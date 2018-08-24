setmetatable(_G, {__index = function(_, k)
   error(("variable " v4r_0x2e_0x2e_ k), v4r_2)
end, __newindex = function(_, k, v)
   error(("declaring global " v4r_0x2e_0x2e_ k), v4r_2)
end})
local puts
do
   local ok, inspect = pcall(require, "inspect")
   if ok then
      puts = function(item, ...)
         print(inspect(item, ...))
         return item
      end
   else
      puts = function(item)
         print(item)
         return item
      end
   end
end
local error2 = function(msg, lvl)
   if (type(msg) == "string") then
   msg = stringGsub(msg, ".-%.lua%:%d+%:%s", "")
end
   lvl = ((lvl or v4r_1) v4r_0x2b_ v4r_1)
   error(msg, lvl)
end
local tableConcat, stringGsub, stringSub, stringByte, stringChar, stringFind, stringUpper, stringLower, stringFormat, stringMatch, stringRep, ioOpen, ioRead, ioClose = table.concat, string.gsub, string.sub, string.byte, string.char, string.find, string.upper, string.lower, string.format, string.match, string.rep, io.open, io.read, io.close
local isAtom, atomCreateValue, atomCreateSymbol, atomIsSymbol, atomIsValue, atomContent, atomPosition, atomToString
do
   local toIdentifier
   do
      local capitalize = function(str)
         return stringGsub(str, "^%l", stringUpper)
      end
      local pascalize = function(str)
         return stringGsub(str, "%-(%w+)", capitalize)
      end
      local escapeChar = function(char)
         return stringLower(stringFormat("0x%X_", stringByte(char)))
      end
      toIdentifier = function(str)
         if stringFind(str, "v4r_") then
         return false,"is prefixed"
      end
         if stringFind(str, "^[_%a][%-_%w]*$") then
         str = pascalize(str)
      end
         if stringFind(str, "^[_%a][%_%w]*$") then
         return true,str
      end
         str = stringGsub(str, "^%-", escapeChar)
         str = pascalize(str)
         str = stringGsub(str, "[^_%w]", escapeChar)
         str = ("v4r_" v4r_0x2e_0x2e_ str)
         return true,str
      end
   end
   local isStore = setmetatable({}, {__mode = "k"})
   isAtom = function(maybeSelf)
      return (isStore[maybeSelf] == true)
   end
   atomCreateValue = function(content, from, to)
      local self = {false, content, from, to}
      isStore[self] = true
      return self
   end
   atomCreateSymbol = function(content, from, to)
      local self = {true, content, from, to}
      isStore[self] = true
      return self
   end
   atomIsSymbol = function(self)
      return (isAtom(self) and self[v4r_1])
   end
   atomIsValue = function(self)
      return (isAtom(self) and not (self[v4r_1]))
   end
   atomContent = function(self)
      return self[v4r_2]
   end
   atomPosition = function(self)
      return self[v4r_3],self[v4r_4]
   end
   atomToString = function(self)
      local content = atomContent(self)
      if atomIsSymbol(self) then
      if (content == "...") then
         return content
      else
         return select(v4r_2, toIdentifier(content))
      end
   elseif (type(content) == "string") then
      return ("\"" v4r_0x2e_0x2e_ content)
   else
      return tostring(content)
   end
   end
end
local isList, listCreateEmpty, listCreateWith, listCons, listHead, listTail, listIsEmpty, listLength, listReverse, listSplit, listToTable, listUnpack, listNext, listPairs, listToString
do
   local isStore = setmetatable({}, {__mode = "k"})
   local emptyList = {}
   isStore[emptyList] = true
   isList = function(value)
      return (isStore[value] == true)
   end
   listCreateEmpty = function()
      return emptyList
   end
   listCreateWith = function(value, ...)
      if (value ~= nil) then
      local self = {value, listCreateWith(...)}
      isStore[self] = true
      return self
   else
      return emptyList
   end
   end
   listCons = function(self, value)
      local self = {value, self}
      isStore[self] = true
      return self
   end
   listHead = function(self)
      return self[v4r_1]
   end
   listTail = function(self)
      return self[v4r_2]
   end
   listIsEmpty = function(self)
      return (self == emptyList)
   end
   listLength = function(self)
      local len = v4r_0
      while self[v4r_2] do
      len = (len v4r_0x2b_ v4r_1)
      self = self[v4r_2]
   end
      return len
   end
   listReverse = function(self)
      local other = listCreateEmpty()
      while self[v4r_2] do
      other = listCons(other, self[v4r_1])
      self = self[v4r_2]
   end
      return other
   end
   listSplit = function(self, at)
      local left, idx, right = {}, v4r_0, self
      for tail,head in listPairs(self) do
      if (idx v4r_0x3e_ at) then
         break
      end
      idx = (idx v4r_0x2b_ v4r_1)
      left[idx] = head
      right = tail
   end
      return listCreateWith(unpack(left)),right
   end
   listToTable = function(self)
      local arr, idx = {}, v4r_0
      while self[v4r_2] do
      idx = (idx v4r_0x2b_ v4r_1)
      arr[idx] = self[v4r_1]
      self = self[v4r_2]
   end
      return arr
   end
   listUnpack = function(self)
      return unpack(listToTable(self))
   end
   listNext = function(self, tail)
      tail = (tail or self)
      if tail then
      return tail[v4r_2],tail[v4r_1]
   end
   end
   listPairs = function(self)
      return listNext,self,self
   end
   listToString = function(self)
      local out, idx = {"("}, v4r_1
      for tail,head in listPairs(self) do
      idx = (idx v4r_0x2b_ v4r_1)
      if isList(head) then
         out[idx] = listToString(head)
      elseif isAtom(head) then
         out[idx] = atomToString(head)
      else
         out[idx] = tostring(head)
      end
      if tail[v4r_2] then
         idx = (idx v4r_0x2b_ v4r_1)
         out[idx] = " "
      end
   end
      out[(idx v4r_0x2b_ v4r_1)] = ")"
      return tableConcat(out, "")
   end
end
local codeCreate, codeFromString, codeFromFile, codePrev, codeNext, codePairs, codePosition, codeLine
do
   codeCreate = function(getNextLine, v4r_name0x3f_)
      return {name = (v4r_name0x3f_ or "in-memory"), getNextLine = getNextLine, lines = {v4r_0 = v4r_0}, buffer = {v4r_0 = v4r_0}, index = v4r_0}
   end
   do
      local v4r_0x2d_nextLineFromString = function(str)
         local idx = v4r_1
         local len = v4r_0x23_str
         return function()
         if (idx v4r_0x3e_0x3d_ len) then
         return
      end
         local subStr = (stringMatch(str, "[^\n]*\n", idx) or stringSub(str, idx))
         local subLen = v4r_0x23_subStr
         idx = (idx v4r_0x2b_ subLen)
         return subStr,stringByte(subStr, v4r_1, subLen)
      end
      end
      codeFromString = function(str, v4r_name0x3f_)
         return codeCreate(v4r_0x2d_nextLineFromString(str), v4r_name0x3f_)
      end
   end
   do
      local v4r_0x2d_nextLineFromFile = function(path)
         local file = assert(ioOpen(path, "r"))
         local closed = false
         return function()
         if closed then
         return
      end
         local line = file.read(file, "*line")
         if line then
         line = (line v4r_0x2e_0x2e_ "\n")
         return line,stringByte(line, v4r_1, v4r_0x23_line)
      else
         ioClose(file)
         closed = true
      end
      end,file
      end
      codeFromFile = function(path)
         local nextLine, file = v4r_0x2d_nextLineFromFile(path)
         return codeCreate(nextLine, path),file
      end
   end
   codePrev = function(self)
      local index = self.index
      if (index == v4r_1) then
      return
   end
      local buffer = self.buffer
      index = (index v4r_0x2d_ v4r_1)
      self.index = index
      local data = buffer[index]
      return data[v4r_1],index
   end
   do
      local v4r_0x2d_appendChars
      v4r_0x2d_appendChars = function(buffer, length, line, column, char, ...)
         if char then
         length = (length v4r_0x2b_ v4r_1)
         if (char == v4r_10) then
            line, column = (line v4r_0x2b_ v4r_1), v4r_0
         elseif (char ~= v4r_13) then
            column = (column v4r_0x2b_ v4r_1)
         end
         buffer[length] = {char, line, column}
         v4r_0x2d_appendChars(buffer, length, line, column, ...)
      else
         buffer[v4r_0] = length
      end
      end
      local v4r_0x2d_nextLine = function(self, buffer, lineStr, ...)
         local lines = self.lines
         local length = (lines[v4r_0] v4r_0x2b_ v4r_1)
         lines[length] = lineStr
         lines[v4r_0] = length
         local bufferLength = buffer[v4r_0]
         local line, column = v4r_1, v4r_0
         if (bufferLength v4r_0x3e_ v4r_0) then
         local data = buffer[bufferLength]
         line, column = data[v4r_2], data[v4r_3]
      end
         v4r_0x2d_appendChars(buffer, bufferLength, line, column, ...)
      end
      codeNext = function(self)
         local index = self.index
         local buffer = self.buffer
         if (index v4r_0x3c_ buffer[v4r_0]) then
         index = (index v4r_0x2b_ v4r_1)
         self.index = index
         local data = buffer[index]
         return data[v4r_1],index
      end
         v4r_0x2d_nextLine(self, buffer, self.getNextLine())
         if (index v4r_0x3c_ buffer[v4r_0]) then
         return codeNext(self)
      end
      end
   end
   codePairs = function(self)
      return codeNext,self
   end
   codePosition = function(self, index)
      local buffer = self.buffer
      local data = buffer[index]
      if data then
      return data[v4r_2],data[v4r_3]
   end
   end
   codeLine = function(self, line)
      if (line == v4r_0) then
      return
   end
      return self.lines[line]
   end
end
local read = function(code, readers)
   for char,index in codePairs(code) do
   local reader = readers[char]
   if reader then
      local result = reader(readers, code, char, index)
      if result then
         return result
      end
   else
      local buf, len = {char}, v4r_1
      local init = index
      local term = index
      for char,index in codePairs(code) do
         if readers[char] then
            codePrev(code)
            break
         end
         len = (len v4r_0x2b_ v4r_1)
         buf[len] = char
         term = index
      end
      return atomCreateSymbol(stringChar(unpack(buf)), init, term)
   end
end
end
local readAll = function(code, readers)
   local form = listCreateEmpty()
   while true do
   local item = read(code, readers)
   if item then
      form = listCons(form, item)
   else
      break
   end
end
   return form
end
local readersCreate
do
   local charHt, charLf, charCr, charSpace, charQuotationMark, charApostrophe, charOpenedParens, charClosedParens, charComma, charHyphen, charSemicolon, charAtSign, charOpenedBrackets, charBackslash, charClosedBrackets, charGraveAccent, charOpenedBraces, charClosedBraces = v4r_9, v4r_10, v4r_13, v4r_32, v4r_34, v4r_39, v4r_40, v4r_41, v4r_44, v4r_45, v4r_59, v4r_64, v4r_91, v4r_92, v4r_93, v4r_96, v4r_123, v4r_125
   local ignoreCharReader = function()
      return
   end
   local commentReader = function(readers, code, char)
      for char in codePairs(code) do
      if (char == charLf) then
         codePrev(code)
         break
      end
   end
   end
   local stringReader = function(readers, code, char, index)
      local buf, len = {}, v4r_0
      local prev = charQuotationMark
      local init = index
      for char,term in codePairs(code) do
      if ((char == charQuotationMark) and (prev ~= charBackslash)) then
         return atomCreateValue(stringChar(unpack(buf)), init, term)
      end
      len = (len v4r_0x2b_ v4r_1)
      buf[len] = char
      prev = char
   end
      error("unclosed string")
   end
   local quoteReader = function(readers, code, char, index)
      local atom = atomCreateSymbol("quote", index, index)
      local item = read(code, readers)
      return listCreateWith(atom, item)
   end
   local quasiquoteReader = function(readers, code, char, index)
      local atom = atomCreateSymbol("quasiquote", index, index)
      local item = read(code, readers)
      return listCreateWith(atom, item)
   end
   local unquoteAndUnquoteSplicingReader = function(readers, code, char, index)
      if (codeNext(code) == charAtSign) then
      local atom = atomCreateSymbol("unquote-splicing", index, index)
      local item = read(code, readers)
      return listCreateWith(atom, item)
   else
      codePrev(code)
      local atom = atomCreateSymbol("unquote", index, index)
      local item = read(code, readers)
      return listCreateWith(atom, item)
   end
   end
   local createFormReader = function(openChar, closeChar)
      local opened = function(readers, code, char, index)
      local form = listCreateEmpty()
      for char,term in codePairs(code) do
      if (char == closeChar) then
         return listReverse(form)
      end
      local reader = readers[char]
      if reader then
         local result = reader(readers, code, char, index)
         if (result ~= nil) then
            form = listCons(form, result)
         end
      else
         codePrev(code)
         form = listCons(form, read(code, readers))
      end
   end
      error("unmatched delimiter")
   end
      local closed = function(readers, code, char)
      error("unexpected delimiter")
   end
      return opened,closed
   end
   local openedParensFormReader, closedParensFormReader = createFormReader(charOpenedParens, charClosedParens)
   local openedBracketsFormReader, closedBracketsFormReader = createFormReader(charOpenedBrackets, charClosedBrackets)
   local openedBracesFormReader, closedBracesFormReader = createFormReader(charOpenedBraces, charClosedBraces)
   readersCreate = function()
      return {[charHt] = ignoreCharReader, [charLf] = ignoreCharReader, [charCr] = ignoreCharReader, [charSpace] = ignoreCharReader, [charSemicolon] = commentReader, [charOpenedParens] = openedParensFormReader, [charClosedParens] = closedParensFormReader, [charOpenedBrackets] = openedBracketsFormReader, [charClosedBrackets] = closedBracketsFormReader, [charOpenedBraces] = openedBracesFormReader, [charClosedBraces] = closedBracesFormReader, [charQuotationMark] = stringReader, [charApostrophe] = quoteReader, [charGraveAccent] = quasiquoteReader, [charComma] = unquoteAndUnquoteSplicingReader}
   end
end
local expand = function(form, macros)
   local head = listHead(form)
   if not (isAtom(head)) then
   error("trying to expand a lua value atom")
end
   if atomIsValue(head) then
   error("trying to expand a non-symbolic atom")
end
   local macro = macros[atomContent(head)]
   if (macro == nil) then
   return false,form
end
   local dong = macro(form, listUnpack(listTail(form)))
   return not ((dong == form)),dong
end
local codegen
do
   local flatten = function(tbl)
      local out, idx = {}, v4r_0
      for n,item in ipairs(tbl) do
      if ((type(item) == "table") and not (isAtom(item))) then
         for n,item in ipairs(item) do
            idx = (idx v4r_0x2b_ v4r_1)
            out[idx] = item
         end
      else
         idx = (idx v4r_0x2b_ v4r_1)
         out[idx] = item
      end
   end
      return out
   end
   local indent
   do
      local store = setmetatable({}, {__mode = "v"})
      indent = function(depth)
         if (depth v4r_0x3c_ v4r_0) then
         depth = v4r_0
      end
         local got = store[depth]
         if got then
         return got
      end
         got = stringRep("   ", depth)
         store[depth] = got
         return got
      end
   end
   local expressions, statements, tables, assigns
   local genMany, genIdentity, genExpression, genStatement, genTableItem, genAssign, genAdd, genSub, genMul, genDiv, genMod, genPow, genConcat, genEq, genNeq, genLt, genLe, genGt, genGe, genAnd, genOr, genNot, genUnm, genLen, genParens, genTable, genKv, genXkv, genDot, genAt, genFunction, genCall, genInvoke, genLocal, genSet, genComma, genDo, genIf, genReturn, genWhile, genRepeat, genFor, genForIn, genBreak, genLabel, genGoto
   local binaryOp = function(operator, separator)
      separator = (separator or " ")
      return function(form, depth)
      local l, o, r = genExpression(listHead(listTail(form)), depth), (operator or listHead(form)), genExpression(listHead(listTail(listTail(form))), depth)
      return flatten({"(", l, separator, o, separator, r, ")"})
   end
   end
   local unaryOp = function(separator, operator)
      separator = (separator or " ")
      return function(form, depth)
      local o, r = (operator or listHead(form)), genExpression(listHead(listTail(form)), depth)
      if not (isAtom(r)) then
      r = flatten({"(", r, ")"})
   end
      return flatten({o, separator, r})
   end
   end
   genMany = function(gen, sep, form, depth)
      local out, idx = {}, v4r_0
      for tail,head in listPairs(form) do
      idx = (idx v4r_0x2b_ v4r_1)
      out[idx] = gen(head, depth)
      if not (listIsEmpty(tail)) then
         idx = (idx v4r_0x2b_ v4r_1)
         out[idx] = sep
      end
   end
      return flatten(out)
   end
   genIdentity = function(form, depth)
      return form
   end
   genExpression = function(form, depth)
      if not (isList(form)) then
      return form
   end
      local head = atomContent(listHead(form))
      local gen = expressions[head]
      if gen then
      return gen(form, depth)
   end
      return genCall(form, depth)
   end
   genStatement = function(form, depth)
      local head = atomContent(listHead(form))
      local gen = statements[head]
      if gen then
      return gen(form, depth)
   end
      return genCall(form, depth)
   end
   genTableItem = function(form, depth)
      if not (isList(form)) then
      return form
   end
      local head = atomContent(listHead(form))
      local gen = tables[head]
      if gen then
      return gen(form, depth)
   end
      return genCall(form, depth)
   end
   genAssign = function(form, depth)
      if not (isList(form)) then
      return form
   end
      local head = atomContent(listHead(form))
      local gen = assigns[head]
      if gen then
      return gen(form, depth)
   end
      error("WTF")
   end
   genAdd = binaryOp()
   genSub = binaryOp()
   genMul = binaryOp()
   genDiv = binaryOp()
   genMod = binaryOp()
   genPow = binaryOp()
   genConcat = binaryOp()
   genEq = binaryOp("==")
   genNeq = binaryOp("~=")
   genLt = binaryOp()
   genLe = binaryOp()
   genGt = binaryOp()
   genGe = binaryOp()
   genAnd = binaryOp()
   genOr = binaryOp()
   genNot = unaryOp(" ")
   genUnm = unaryOp("")
   genLen = unaryOp("")
   genParens = function(form, depth)
      local x = genExpression(listHead(listTail(form)), depth)
      return flatten({"(", x, ")"})
   end
   genTable = function(form, depth)
      local i = genMany(genTableItem, ", ", listTail(form), depth)
      return flatten({"{", i, "}"})
   end
   genKv = function(form, depth)
      local k, v = listHead(listTail(form)), genExpression(listHead(listTail(listTail(form))), depth)
      return flatten({k, " = ", v})
   end
   genXkv = function(form, depth)
      local k, v = genExpression(listHead(listTail(form)), depth), genExpression(listHead(listTail(listTail(form))), depth)
      return flatten({"[", k, "] = ", v})
   end
   genDot = function(form, depth)
      local l, p = genExpression(listHead(listTail(form)), depth), listHead(listTail(listTail(form)))
      return flatten({l, ".", p})
   end
   genAt = function(form, depth)
      local l, p = genExpression(listHead(listTail(form)), depth), genExpression(listHead(listTail(listTail(form))), depth)
      return flatten({l, "[", p, "]"})
   end
   genFunction = function(form, depth)
      local p, b, i1, i2 = genMany(genIdentity, ", ", listHead(listTail(form)), depth), genMany(genStatement, {"\n", indent((depth v4r_0x2b_ v4r_1))}, listTail(listTail(form)), depth), indent((depth v4r_0x2b_ v4r_1)), indent(depth)
      return flatten({"function(", p, ")\n", i1, b, "\n", i2, "end"})
   end
   genCall = function(form, depth)
      local l, p = genExpression(listHead(form), depth), genMany(genExpression, ", ", listTail(form), depth)
      return flatten({l, "(", p, ")"})
   end
   genInvoke = function(form, depth)
      local x, m, p = genExpression(listHead(listTail(form)), depth), listHead(listTail(listTail(form))), genMany(genExpression, ", ", listTail(listTail(form)), depth)
      return flatten({x, ":", m, "(", p, ")"})
   end
   genSet = function(form, depth)
      local x, v = genAssign(listHead(listTail(form)), depth), genMany(genExpression, ", ", listTail(listTail(form)), depth)
      return flatten({x, " = ", v})
   end
   genLocal = function(form, depth)
      local v = genMany(genIdentity, ", ", listTail(form), depth)
      return flatten({"local ", v})
   end
   genComma = function(form, depth)
      return flatten(genMany(genIdentity, ", ", listTail(form), depth))
   end
   genDo = function(form, depth)
      local b, i1, i2 = genMany(genStatement, {"\n", indent((depth v4r_0x2b_ v4r_1))}, listTail(form), (depth v4r_0x2b_ v4r_1)), indent((depth v4r_0x2b_ v4r_1)), indent(depth)
      return flatten({"do\n", i1, b, "\n", i2, "end"})
   end
   genIf = function(form, depth)
      local firstCond, rest = listHead(listTail(form)), listTail(listTail(form))
      local x, b, i1, i2 = genExpression(listHead(firstCond), depth), genMany(genStatement, {"\n", indent((depth v4r_0x2b_ v4r_1))}, listTail(firstCond), (depth v4r_0x2b_ v4r_1)), indent((depth v4r_0x2b_ v4r_1)), indent(depth)
      local out, idx = {"if ", x, " then\n", i1, b}, v4r_5
      for tail,head in listPairs(rest) do
      local x, b = genExpression(listHead(head), depth), genMany(genStatement, {"\n", indent((depth v4r_0x2b_ v4r_1))}, listTail(head), (depth v4r_0x2b_ v4r_1))
      if (listIsEmpty(tail) and (atomIsSymbol(x) and (atomContent(x) == "else"))) then
         out[(idx v4r_0x2b_ v4r_1)] = "\n"
         out[(idx v4r_0x2b_ v4r_2)] = i2
         out[(idx v4r_0x2b_ v4r_3)] = "else\n"
         out[(idx v4r_0x2b_ v4r_4)] = i1
         idx = (idx v4r_0x2b_ v4r_5)
      else
         out[(idx v4r_0x2b_ v4r_1)] = "\n"
         out[(idx v4r_0x2b_ v4r_2)] = i2
         out[(idx v4r_0x2b_ v4r_3)] = "elseif "
         out[(idx v4r_0x2b_ v4r_4)] = x
         out[(idx v4r_0x2b_ v4r_5)] = " then\n"
         out[(idx v4r_0x2b_ v4r_6)] = i1
         idx = (idx v4r_0x2b_ v4r_7)
      end
      out[idx] = b
   end
      out[(idx v4r_0x2b_ v4r_1)] = "\n"
      out[(idx v4r_0x2b_ v4r_2)] = i2
      out[(idx v4r_0x2b_ v4r_3)] = "end"
      return flatten(out)
   end
   genReturn = function(form, depth)
      local p = genMany(genExpression, ",", listTail(form), depth)
      return flatten({"return ", p})
   end
   genWhile = function(form, depth)
      local x, b, i1, i2 = genExpression(listHead(listTail(form)), depth), genMany(genStatement, {"\n", indent((depth v4r_0x2b_ v4r_1))}, listTail(listTail(form)), (depth v4r_0x2b_ v4r_1)), indent((depth v4r_0x2b_ v4r_1)), indent(depth)
      return flatten({"while ", x, " do\n", i1, b, "\n", i2, "end"})
   end
   genRepeat = function(form, depth)
      local till, body = listSplit(listReverse(listTail(form)), v4r_1)
      local t, b, i1, i2 = genExpression(listHead(listTail(listReverse(till))), depth), genMany(genStatement, {"\n", indent((depth v4r_0x2b_ v4r_1))}, listReverse(body), (depth v4r_0x2b_ v4r_1)), indent((depth v4r_0x2b_ v4r_1)), indent(depth)
      return flatten({"repeat\n", i1, b, "\n", i2, "until ", t})
   end
   genFor = function(form, depth)
      local opts = listHead(listTail(form))
      local iter, walk = listHead(opts), listTail(opts)
      local step = listHead(listTail(walk))
      local i, x, t, b, i1, i2 = listHead(iter), genExpression(listHead(listTail(iter)), depth), genExpression(listHead(walk), depth), genMany(genStatement, {"\n", indent((depth v4r_0x2b_ v4r_1))}, listTail(listTail(form)), (depth v4r_0x2b_ v4r_1)), indent((depth v4r_0x2b_ v4r_1)), indent(depth)
      if step then
      local s = genExpression(step, depth)
      return flatten({"for ", i, "=", x, ",", t, ",", s, " do\n", i1, b, "\n", i2, "end"})
   end
      return flatten({"for ", i, "=", x, ",", t, " do\n", i1, b, "\n", i2, "end"})
   end
   genForIn = function(form, depth)
      local v, x, b, i1, i2 = genMany(genIdentity, ",", listHead(listTail(form)), depth), genMany(genExpression, ",", listHead(listTail(listTail(form))), depth), genMany(genStatement, {"\n", indent((depth v4r_0x2b_ v4r_1))}, listTail(listTail(listTail(form))), (depth v4r_0x2b_ v4r_1)), indent((depth v4r_0x2b_ v4r_1)), indent(depth)
      return flatten({"for ", v, " in ", x, " do\n", i1, b, "\n", i2, "end"})
   end
   genBreak = function(form, depth)
      return listHead(form)
   end
   genLabel = function(form, depth)
      local n = listHead(listTail(form))
      return {"::", n, "::"}
   end
   genGoto = function(form, depth)
      local n = listHead(listTail(form))
      return {"goto", n}
   end
   expressions = {"+" = genAdd, "-" = genSub, "*" = genMul, "/" = genDiv, "%" = genMod, "^" = genPow, ".." = genConcat, "==" = genEq, "~=" = genNeq, "<" = genLt, "<=" = genLe, ">" = genGt, ">=" = genGe, "and" = genAnd, "or" = genOr, "not" = genNot, "--" = genUnm, "#" = genLen, "parens" = genParens, "table" = genTable, "." = genDot, "at" = genAt, "function" = genFunction, ":" = genInvoke}
   statements = {"local" = genLocal, "=" = genSet, "do" = genDo, "if" = genIf, "return" = genReturn, "while" = genWhile, "repeat" = genRepeat, "for" = genFor, "for-in" = genForIn, "break" = genBreak, "label" = genLabel, "goto" = genGoto}
   tables = {"+" = genAdd, "-" = genSub, "*" = genMul, "/" = genDiv, "%" = genMod, "^" = genPow, ".." = genConcat, "==" = genEq, "~=" = genNeq, "<" = genLt, "<=" = genLe, ">" = genGt, ">=" = genGe, "and" = genAnd, "or" = genOr, "not" = genNot, "--" = genUnm, "#" = genLen, "parens" = genParens, "table" = genTable, "." = genDot, "at" = genAt, "function" = genFunction, ":" = genInvoke, "kv" = genKv, "xkv" = genXkv}
   assigns = {"local" = genLocal, "many" = genComma, "." = genDot, "at" = genAt}
   codegen = function(form, depth)
      local got = genStatement(form, (depth or v4r_0))
      local out, len = {}, v4r_1
      for n,item in ipairs(got) do
      if isAtom(item) then
         out[n] = atomToString(item)
      else
         out[n] = tostring(item)
      end
      len = n
   end
      out[(len v4r_0x2b_ v4r_1)] = "\n"
      return tableConcat(out, "")
   end
end
local macrosCreate
do
   local isKeyword
   do
      local keywords = {"and" = true, "break" = true, "do" = true, "else" = true, "elseif" = true, "end" = true, "false" = true, "for" = true, "function" = true, "goto" = true, "if" = true, "in" = true, "local" = true, "nil" = true, "not" = true, "or" = true, "repeat" = true, "return" = true, "true" = true, "until" = true, "while" = true, "then" = true}
      isKeyword = function(str)
         return (keywords[str] == true)
      end
   end
   macrosCreate = function()
      return {}
   end
end
local transform = function(form, transforms)
   return form
end
local transformsBeforeCreate
do
   transformsBeforeCreate = function()
      return {}
   end
end
local transformsAfterCreate
do
   transformsAfterCreate = function()
      return {}
   end
end
local compileCode = function(code, output, opts)
   local readers, macros, transformsBefore, transformsAfter = ((opts and opts.readers) or readersCreate()), ((opts and opts.macros) or macrosCreate()), ((opts and opts.transformsBefore) or transformsBeforeCreate()), ((opts and opts.transformsAfter) or transformsAfterCreate())
   while true do
   local form, v4r_expanded0x3f_ = read(code, readers), false
   if (form == nil) then
      break
   end
   form = transform(form, transformsBefore)
   if (form == nil) then
      gotoskip
   end
   repeat
      v4r_expanded0x3f_, form = expand(form, macros)
      if (form == nil) then
         gotoskip
      end
      if v4r_expanded0x3f_ then
         form = transform(form, transformsAfter)
         if (form == nil) then
            gotoskip
         end
      end
   until not v4r_expanded0x3f_
   output(codegen(form))
   ::skip::
end
end
local print2 = function(str)
   io.stdout.write(io.stdout, str)
end
local code = codeFromFile("lisp.lisp")
compileCode(code, print2)
print2("\n")

