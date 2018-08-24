;;;; high priority:
;;;;
;;;; - add codegen
;;;; - add transforms support
;;;;   - symbol/symbol support
;;;; - add error reporting
;;;; - finish bootstrapping
;;;; - rename some special forms
;;;;   - = -> set
;;;;   - == -> =
;;;;   - ~= -> !=
;;;; - add compatibility for luajit 5.1
;;;;
;;;; medium priority:
;;;;
;;;; - add quasiquote/unquote/unquote-splicing support
;;;;   - this will probably involve adding some tranforms
;;;; - add 'everything is an expression' transform
;;;; - break compatibility with `#` and `-` readers
;;;;
;;;; low priority:
;;;;
;;;; - add sourcemapped error reporting for runtime
;;;; - add a runtime library tranform
;;;;
;;;; it will probably need 2kloc :T

;;;; dev mode helpers

;;; disable undefined globals
(setmetatable _G
  {table
    (kv __index
      (function [_ k]
        (error (.. "variable " k " is not declared") 2)))
    (kv __newindex
      (function [_ k v]
        (error (.. "declaring global " k " to " (tostring v)) 2)))})

;;; useful inspect->print function
(local puts) ; (a): a
(do
  (= (local ok inspect) (pcall require "inspect"))
  (if [ok
       (= puts
          (function [item ...]
            (print (inspect item ...))
            (return item)))]
      [else
       (= puts
          (function [item]
            (print item)
            (return item)))]))

;;;; helper functions

;;; throws a previously catched error
(= (local error2); (str, num): nil
   (function [msg lvl]
    (if [(== (type msg) "string")
         (= msg (string-gsub msg ".-%.lua%:%d+%:%s" ""))])
    (= lvl (+ (or lvl 1) 1))
    (error msg lvl)))

;;;; required lua functions

(= (local table-concat ; (table a b, str?, num?, num?): str
          string-gsub ; (str, str, str | (str): str, num): str
          string-sub ; (str, num, num): str
          string-byte ; (str, num?, num?): ...num
          string-char ; (...num): str
          string-find ; (str, str, num, bool): (num, numbe)?
          string-upper ; (str): str
          string-lower ; (str): str
          string-format ; (str, ...any): str
          string-match ; (str, str, num): any...
          string-rep ; (str, num): str
          io-open ; (str, str): handle | (nil, str, num)
          io-read ; (handle, str): str
          io-close) ; (handle): nil
   (. table concat) (. string gsub) (. string sub) (. string byte)
   (. string char) (. string find) (. string upper) (. string lower)
   (. string format) (. string match) (. string rep) (. io open) (. io read)
   (. io close))

;;;; compiler types

;;; immutable atom type, used to represent literals and values in s-expressions
(local is-atom ; (any): bool
       atom-create-value ; (a, num, num): atom a
       atom-create-symbol ; (str, num, num): atom str
       atom-is-symbol ; (atom a): bool
       atom-is-value ; (atom a): bool
       atom-content ; (atom a): a
       atom-position ; (atom a): num, num
       atom-to-string) ; (atom a): str
(do
  ;; stores available atoms
  (= (local is-store) (setmetatable {table} {table (kv __mode "k")}))

  ;;; returns true when the value is an atom
  (= is-atom
     (function [maybe-self] (return (== (at is-store maybe-self) true))))

  ;;; creates an atom for a value
  (= atom-create-value
     (function [content from to]
      (= (local self)
         {table
          false
          content
          from
          to})
      (= (at is-store self) true)
      (return self)))

  ;;; creates an atom for a symbol
  (= atom-create-symbol
     (function [content from to]
      (= (local self)
         {table
          true
          content
          from
          to})
      (= (at is-store self) true)
      (return self)))

  ;;; returns true when the atom is a symbol
  (= atom-is-symbol
     (function [self]
      (return (and (is-atom self) (at self 1)))))

  ;;; returns true when the atom is an value
  (= atom-is-value
     (function [self]
      (return (and (is-atom self) (not (at self 1))))))

  ;;; returns atom content
  (= atom-content
     (function [self] (return (at self 2))))

  ;;; returns atom position
  (= atom-position
     (function [self] (return (at self 3) (at self 4))))

  ;;; returns atom string representation
  (= atom-to-string
     (function [self]
      (= (local content) (atom-content self))
      (if [(atom-is-symbol self) (return content)]
          [(== (type content) "string") (return (.. "\"" content "\""))]
          [else (return (tostring content))]))))

;;; immutable linked lists, metatables are allowed but will only affect the
;;; first cons cell
(local is-list ; (any): bool
       list-create-empty ; (): list
       list-create-with ; (...): list
       list-cons ; (list a, a): list a
       list-head ; (list a): a?
       list-tail ; (list a): list a
       list-is-empty ; (list a): bool
       list-length ; (list a): num
       list-reverse ; (list a): list a
       list-split ; (list a)
       list-to-table ; (list a): table num a
       list-unpack ; (list a): ...a
       list-next ; (list a, list a?): (list a, a)?
       list-pairs ; (list a): ((_, list a): list a, a), list a, list a
       list-to-string) ; (list a): str
(do
  ;; stores available lists
  (= (local is-store) (setmetatable {table} {table (kv __mode "k")}))

  ;; empty list cache (no problem, they are immutable)
  (= (local empty-list) {table})
  (= (at is-store empty-list) true)

  ;;; returns true when the value is a linked list
  (= is-list
     (function [value] (return (== (at is-store value) true))))

  ;;; returns an empty list
  (= list-create-empty
     (function [] (return empty-list)))

  ;;; creates a list from vararg parameters
  (= list-create-with
     (function [value ...]
      (if [(~= value nil)
           (= (local self) {table value (list-create-with ...)})
           (= (at is-store self) true)
           (return self)]
          [else (return empty-list)])))

  ;;; adds an element to the front of a list
  (= list-cons
    (function [self value]
      (= (local self) {table value self})
      (= (at is-store self) true)
      (return self)))

  ;;; extracts the first element of the list
  (= list-head
     (function [self] (return (at self 1))))

  ;;; extracts the rest of the list
  (= list-tail
     (function [self] (return (at self 2))))

  ;;; returns true when the list is empty
  (= list-is-empty
    (function [self]
      (return (== self empty-list))))

  ;;; returns list length
  (= list-length
     (function [self]
      (= (local len) 0)
      (while (at self 2)
        (= len (+ len 1))
        (= self (at self 2)))
      (return len)))

  ;;; reverts the list
  (= list-reverse
    (function [self]
      (= (local other) (list-create-empty))
      (while (at self 2)
        (= other (list-cons other (at self 1)))
        (= self (at self 2)))
      (return other)))

  ;;; splits a list into two at given point
  (= list-split
     (function [self at]
      (= (local left idx right) {table} 0 self)
      (for-in [tail head] [(list-pairs self)]
        (if [(> idx at) (break)])
        (= idx (+ idx 1))
        (= (at left idx) head)
        (= right tail))
      (return (list-create-with (unpack left)) right)))

  ;;; turns the list into a table
  (= list-to-table
     (function [self]
      (= (local arr idx) {table} 0)
      (while (at self 2)
        (= idx (+ idx 1))
        (= (at arr idx) (at self 1))
        (= self (at self 2)))
      (return arr)))

  ;;; converts a list into a table and unpacks it
  (= list-unpack
     (function [self] (return (unpack (list-to-table self)))))

  ;;; returns list tail and its next element
  (= list-next
     (function [self tail]
      (= tail (or tail self))
      (if [tail (return (at tail 2) (at tail 1))])))

  ;;; returns iterator for list pairs for next tail and head
  (= list-pairs
     (function [self] (return list-next self self)))

  ;;; returns a string representation of the list
  (= list-to-string
     (function [self]
       (= (local out idx) {table "("} 1)
       (for-in [tail head] [(list-pairs self)]
        (= idx (+ idx 1))
        (if [(is-list head) (= (at out idx) (list-to-string head))]
            [(is-atom head) (= (at out idx) (atom-to-string head))]
            [else (= (at out idx) (tostring head))])
        (if [(at tail 2)
             (= idx (+ idx 1))
             (= (at out idx) " ")]))
      (= (at out (+ idx 1)) ")")
      (return (table-concat out "")))))

;;; mutable code type used to dynamically read files,
;;; the source function must return lines
(local code-create ; ((): str, ...num, str?): code
       code-from-string ; (str, str?): code
       code-from-file ; (str, str?): code
       code-prev ; (code): (num, num)?
       code-next ; (code): (num, num)?
       code-pairs ; (code): ((code): (num, num)?, code)
       code-position ; (code, num): (num, num)?
       code-line) ; (code, num): str?
(do
  ;;; creates a code stream using given `get-next-line' function
  (= code-create
     (function [get-next-line name?]
      (return
        {table
          (kv name (or name? "in-memory"))
          (kv get-next-line get-next-line)
          (kv lines {table (kv 0 0)})
          (kv buffer {table (kv 0 0)})
          (kv index 0)})))

  ;;; creates a code stream that traverses given string
  (do ; code-from-string
    (= (local -next-line-from-string)
      (function [str]
        (= (local idx) 1)
        (= (local len) (# str))
        (return
          (function []
            (if [(>= idx len) (return)])
            (= (local sub-str)
              (or (string-match str "[^\n]*\n" idx)
                  (string-sub str idx)))
            (= (local sub-len) (# sub-str))
            (= idx (+ idx sub-len))
            (return sub-str (string-byte sub-str 1 sub-len))))))
    (= code-from-string
      (function [str name?]
        (return (code-create (-next-line-from-string str) name?)))))

  ;;; creates a code stream that traverses given string
  (do ; code-from-file
    (= (local -next-line-from-file)
      (function [path]
        (= (local file) (assert (io-open path "r")))
        (= (local closed) false)
        (return
          (function []
            (if [closed (return)])
            (= (local line) ((. file read) file "*line"))
            (if [line
                 (= line (.. line "\n"))
                 (return line (string-byte line 1 (# line)))]
                [else
                  (io-close file)
                  (= closed true)]))
          file)))
    (= code-from-file
      (function [path]
        (= (local next-line file) (-next-line-from-file path))
        (return (code-create next-line path) file))))

  ;;; moves code one step backward and returns current character
  (= code-prev
     (function [self]
      (= (local index) (. self index))
      (if [(== index 1) (return)])
      (= (local buffer) (. self buffer))
      (= index (- index 1))
      (= (. self index) index)
      (= (local data) (at buffer index))
      (return (at data 1) index)))

  ;;; moves code one step forward and returns current character
  (do ; code-next
    (local -append-chars)
    (= -append-chars
       (function [buffer length line column char ...]
        (if [char
             (= length (+ length 1))
             ;; updates line/column data
             (if [(== char 10) (= (many line column) (+ line 1) 0)]
                 [(~= char 13) (= column (+ column 1))])
             ;; writes index data
             (= (at buffer length) {table char line column})
             ;; continue vararg traversal
             (-append-chars buffer length line column ...)]
            [else
             ;; last element, update buffer length
             (= (at buffer 0) length)])))

    (= (local -next-line)
       (function [self buffer line-str ...]
        ;; push line string & update array length
        (= (local lines) (. self lines))
        (= (local length) (+ (at lines 0) 1))
        (= (at lines length) line-str)
        (= (at lines 0) length)
        ;; fetch last line/column data
        (= (local buffer-length) (at buffer 0))
        (= (local line column) 1 0)
        (if [(> buffer-length 0)
             (= (local data) (at buffer buffer-length))
             (= (many line column) (at data 2) (at data 3))])
        ;; append characters
        (-append-chars buffer buffer-length line column ...)))

    (= code-next
      (function [self]
        (= (local index) (. self index))
        (= (local buffer) (. self buffer))
        (if [(< index (at buffer 0))
             ;; return next character
             (= index (+ index 1))
             (= (. self index) index)
             (= (local data) (at buffer index))
             (return (at data 1) index)])
        ;; fetch next line then return next character
        (-next-line self buffer ((. self get-next-line)))
        (if [(< index (at buffer 0))
             (return (code-next self))]))))

  ;;; returns a code iterator
  (= code-pairs
     (function [self] (return code-next self)))

  ;;; returns position for given index
  (= code-position
     (function [self index]
      (= (local buffer) (. self buffer))
      (= (local data) (at buffer index))
      (if [data (return (at data 2) (at data 3))])))

  ;;; returns whole line
  (= code-line
     (function [self line]
        (if [(== line 0) (return)])
        (return (at (. self lines) line)))))

;;;; compiler functions

;;; calls a function from the readtable or reads an atom
(= (local read) ; (code, readers): (atom any | list any)?
   (function [code readers]
    (for-in [char index] [(code-pairs code)]
      (= (local reader) (at readers char))
      (if [reader
           (= (local result) (reader readers code char index))
           (if [result (return result)])]
          [else
            (= (local buf len) {table char} 1)
            (= (local init) index)
            (= (local term) index)
            (for-in [char index] [(code-pairs code)]
              (if [(at readers char)
                   (code-prev code)
                   (break)])
              (= len (+ len 1))
              (= (at buf len) char)
              (= term index))
            (return
              (atom-create-symbol (string-char (unpack buf)) init term))]))))

;;; reads the whole file, may be used to parse files containing data
(= (local read-all) ; (code, readers): list (atom any | list any)
   (function [code readers]
    (= (local form) (list-create-empty))
    (while true
      (= (local item) (read code readers))
      (if [item (= form (list-cons form item))]
          [else (break)]))
    (return form)))

;;; returns a readers table
(local readers-create) ; (): readers
(do
  (= (local char-ht char-lf char-cr char-space char-quotation-mark
            char-apostrophe char-opened-parens char-closed-parens
            char-comma char-hyphen char-semicolon char-at-sign
            char-opened-brackets char-backslash char-closed-brackets
            char-grave-accent char-opened-braces char-closed-braces)
     9 10 13 32 34 39 40 41 44 45 59 64 91 92 93 96 123 125)

  ;;; ignores a single char
  (= (local ignore-char-reader) (function [] (return)))

  ;;; ignores a chars until a newline
  (= (local comment-reader)
     (function [readers code char]
      (for-in [char] [(code-pairs code)]
        (if [(== char char-lf)
             (code-prev code)
             (break)]))))

  ;;; reads a negative number
  ;; TODO: create the reader

  ;;; reads a string
  (= (local string-reader)
     (function [readers code char index]
      (= (local buf len) {table} 0)
      (= (local prev) char-quotation-mark)
      (= (local init) index)
      (for-in [char term] [(code-pairs code)]
        (if [(and (== char char-quotation-mark) (~= prev char-backslash))
             (return
              (atom-create-value (string-char (unpack buf)) init term))])
        (= len (+ len 1))
        (= (at buf len) char)
        (= prev char))
      (error "unclosed string")))

  ;;; reads quote
  (= (local quote-reader)
     (function [readers code char index]
      (= (local atom) (atom-create-symbol "quote" index index))
      (= (local item) (read code readers))
      (return (list-create-with atom item))))

  ;;; reads quasiquote
  (= (local quasiquote-reader)
     (function [readers code char index]
      (= (local atom) (atom-create-symbol "quasiquote" index index))
      (= (local item) (read code readers))
      (return (list-create-with atom item))))

  ;;; reads unquote and unquote-splicing
  (= (local unquote-and-unquote-splicing-reader)
     (function [readers code char index]
      (if [(== (code-next code) char-at-sign)
           (= (local atom) (atom-create-symbol "unquote-splicing" index index))
           (= (local item) (read code readers))
           (return (list-create-with atom item))]
          [else

           (code-prev code)
           (= (local atom) (atom-create-symbol "unquote" index index))
           (= (local item) (read code readers))
           (return (list-create-with atom item))])))

  ;;; returns readers for opened and closed forms
  (= (local create-form-reader)
     (function [open-char close-char]
      (= (local opened)
         (function [readers code char index]
          (= (local form) (list-create-empty))
          (for-in [char term] [(code-pairs code)]
            (if [(== char close-char)
                 (return (list-reverse form))])
            (= (local reader) (at readers char))
            (if [reader
                 (= (local result) (reader readers code char index))
                 (if [(~= result nil) (= form (list-cons form result))])]
                [else
                 (code-prev code)
                 (= form (list-cons form (read code readers)))]))
          (error "unmatched delimiter")))
      (= (local closed)
         (function [readers code char]
          (error "unexpected delimiter")))
      (return opened closed)))

  ;; readers for parens
  (= (local opened-parens-form-reader closed-parens-form-reader)
     (create-form-reader char-opened-parens char-closed-parens))

  ;; readers for brackets
  (= (local opened-brackets-form-reader closed-brackets-form-reader)
     (create-form-reader char-opened-brackets char-closed-brackets))

  ;; readers for braces
  (= (local opened-braces-form-reader closed-braces-form-reader)
     (create-form-reader char-opened-braces char-closed-braces))

  (= readers-create
     (function []
      (return
        {table
          (xkv char-ht ignore-char-reader)
          (xkv char-lf ignore-char-reader)
          (xkv char-cr ignore-char-reader)
          (xkv char-space ignore-char-reader)
          (xkv char-semicolon comment-reader)
          (xkv char-opened-parens opened-parens-form-reader)
          (xkv char-closed-parens closed-parens-form-reader)
          (xkv char-opened-brackets opened-brackets-form-reader)
          (xkv char-closed-brackets closed-brackets-form-reader)
          (xkv char-opened-braces opened-braces-form-reader)
          (xkv char-closed-braces closed-braces-form-reader)
          (xkv char-quotation-mark string-reader)
          (xkv char-apostrophe quote-reader)
          (xkv char-grave-accent quasiquote-reader)
          (xkv char-comma unquote-and-unquote-splicing-reader)}))))

;;; performs one form expansion, doesn't expand sub forms
(= (local expand) ; (list any, macros): bool, (list any | atom any)?
   (function [form macros]
    (= (local head) (list-head form))
    (if [(not (is-atom head)) (error "trying to expand a lua value atom")])
    (if [(atom-is-value head) (error "trying to expand a non-symbolic atom")])
    (= (local macro) (at macros (atom-content head)))
    (if [(== macro nil) (return false form)])
    (= (local dong) (macro form (list-unpack (list-tail form))))
    (return (not (== dong form)) dong)))

;;; generates code for given form, it's pretty dumb because macros already
;;; perform validation
(local codegen) ; (form, num?): str
(do
  ;;; converts string into a valid identifier, fails when the identifier is
  ;;; prefixed with `v4r_'
  (local to-identifier) ; (str): str
  (do
    (= (local capitalize)
      (function [str] (return (string-gsub str "^%l" string-upper))))

    (= (local pascalize)
      (function [str] (return (string-gsub str "%-(%w+)" capitalize))))

    (= (local escape-char)
      (function [char]
        (return (string-lower (string-format "0x%X_" (string-byte char))))))

    (= to-identifier
      (function [str]
        (if [(string-find str "v4r_") (return false "is prefixed")])
        (if [(string-find str "^[_%a][%-_%w]*$") (= str (pascalize str))])
        (if [(string-find str "^[_%a][%_%w]*$") (return true str)])
        (= str (string-gsub str "^%-" escape-char))
        (= str (pascalize str))
        (= str (string-gsub str "[^_%w]" escape-char))
        (= str (.. "v4r_" str))
        (return true str))))

  ;;; flattens a table one level, also useful for shallow copies
  (= (local flatten) ; (table num (v | table num v)): table num v
     (function [tbl]
      (= (local out idx) {table} 0)
      (for-in [n item] [(ipairs tbl)]
        (if [(and (== (type item) "table") (not (is-atom item)))
             (for-in [n item] [(ipairs item)]
              (= idx (+ idx 1))
              (= (at out idx) item))]
            [else
              (= idx (+ idx 1))
              (= (at out idx) item)]))
      (return out)))

  ;;; returns indentation for given depth
  (local indent) ; (num): str
  (do
    (= (local store) (setmetatable {table} {table (kv __mode "v")}))

    (= indent
       (function [depth]
        (if [(< depth 0) (= depth 0)])
        (= (local got) (at store depth))
        (if [got (return got)])
        (= got (string-rep "   " depth))
        (= (at store depth) got)
        (return got))))

  ;;; returns a function to generate generic binary operators
  (= (local binary-op) ; (str?): ((list form, num): table num (atom | any))
     (function [operator separator]
      (= separator (or separator " "))
      (return
        (function [form depth]
          (= (local l o r)
             (gen-expression (list-head (list-tail form)) depth)
             (or operator (list-head form))
             (gen-expression (list-head (list-tail (list-tail form))) depth))
          (return (flatten {table "(" l separator o separator r ")"}))))))

  ;;; returns a function to generate generic binary operators
  (= (local unary-op) ; (str?): ((list form, num): table num (atom | any))
     (function [separator operator]
      (= separator (or separator " "))
      (return
        (function [form depth]
          (= (local o r)
             (or operator (list-head form))
             (gen-expression (list-head (list-tail form)) depth))
          (if [(not (is-atom r))
               (= r (flatten {table "(" r ")"}))])
          (return (flatten {table o separator r}))))))

  ;; generator aggregators
  (local expressions statements tables assigns)

  ;; generator functions
  (local gen-many gen-identity
         gen-expression gen-statement gen-table-item gen-assign
         gen-add gen-sub gen-mul gen-div gen-mod gen-pow gen-concat
         gen-eq gen-neq gen-lt gen-le gen-gt gen-ge
         gen-and gen-or gen-not
         gen-unm gen-len
         gen-parens
         gen-table gen-kv gen-xkv gen-dot gen-at
         gen-function gen-call gen-invoke
         gen-local gen-set gen-comma
         gen-do gen-if gen-return
         gen-while gen-repeat gen-for gen-for-in gen-break
         gen-label gen-goto)

  ;;; tries to generate each element of the list with given generator
  (= gen-many ; (generator, str, list form, num): table num (atom | any)
     (function [gen sep form depth]
      (= (local out idx) {table} 0)
      (for-in [tail head] [(list-pairs form)]
        (= idx (+ idx 1))
        (= (at out idx) (gen head depth))
        (if [(not (list-is-empty tail))
             (= idx (+ idx 1))
             (= (at out idx) sep)]))
      (return (flatten out))))

  ;;; generates an expression
  (= gen-identity ; (a, num): a
     (function [form depth] (return form)))

  ;;; generates an expression
  (= gen-expression ; (list form, num): table num (atom | any)
     (function [form depth]
      (if [(not (is-list form)) (return form)])
      (= (local head) (atom-content (list-head form)))
      (= (local gen) (at expressions head))
      (if [gen (return (gen form depth))])
      (return (gen-call form depth))))

  ;;; generates a statement
  (= gen-statement ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local head) (atom-content (list-head form)))
      (= (local gen) (at statements head))
      (if [gen (return (gen form depth))])
      (return (gen-call form depth))))

  ;;; generates an table item
  (= gen-table-item ; (list form, num): table num (atom | any)
     (function [form depth]
      (if [(not (is-list form)) (return form)])
      (= (local head) (atom-content (list-head form)))
      (= (local gen) (at tables head))
      (if [gen (return (gen form depth))])
      (return (gen-call form depth))))

  ;;; generates an table item
  (= gen-assign ; (list form, num): table num (atom | any)
     (function [form depth]
      (if [(not (is-list form)) (return form)])
      (= (local head) (atom-content (list-head form)))
      (= (local gen) (at assigns head))
      (if [gen (return (gen form depth))])
      (error "WTF")))

  ;;; operatiors
  (= gen-add (binary-op))
  (= gen-sub (binary-op))
  (= gen-mul (binary-op))
  (= gen-div (binary-op))
  (= gen-mod (binary-op))
  (= gen-pow (binary-op))
  (= gen-concat (binary-op))
  (= gen-eq (binary-op "=="))
  (= gen-neq (binary-op "~="))
  (= gen-lt (binary-op))
  (= gen-le (binary-op))
  (= gen-gt (binary-op))
  (= gen-ge (binary-op))
  (= gen-and (binary-op))
  (= gen-or (binary-op))
  (= gen-not (unary-op " "))
  (= gen-unm (unary-op ""))
  (= gen-len (unary-op ""))

  ;;; wraps expression in parens
  (= gen-parens
     (function [form depth]
      (= (local x) (gen-expression (list-head (list-tail form)) depth))
      (return (flatten {table "(" x ")"}))))

  ;;; creates a table
  (= gen-table ; (list form, num): table num (atom | any)
      (function [form depth]
       (= (local i) (gen-many gen-table-item ", " (list-tail form) depth))
       (return (flatten {table "{" i "}"}))))

  ;;; creates a table field from symbol
  (= gen-kv ; (list form, num): table num (atom | any)
      (function [form depth]
        (= (local k v)
           (list-head (list-tail form))
           (gen-expression (list-head (list-tail (list-tail form))) depth))
        (return (flatten {table k " = " v}))))

  ;;; creates a table field from expression
  (= gen-xkv ; (list form, num): table num (atom | any)
      (function [form depth]
        (= (local k v)
           (gen-expression (list-head (list-tail form)) depth)
           (gen-expression (list-head (list-tail (list-tail form))) depth))
        (return (flatten {table "[" k "] = " v}))))

  ;;; access table field with symbol
  (= gen-dot ; (list form, num): table num (atom | any)
      (function [form depth]
       (= (local l p)
          (gen-expression (list-head (list-tail form)) depth)
          (list-head (list-tail (list-tail form))))
       (return (flatten {table l "." p}))))

  ;;; access table field with value
  (= gen-at ; (list form, num): table num (atom | any)
      (function [form depth]
       (= (local l p)
          (gen-expression (list-head (list-tail form)) depth)
          (gen-expression (list-head (list-tail (list-tail form))) depth))
       (return (flatten {table l "[" p "]"}))))

  ;;; creates a function
  (= gen-function ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local p b i1 i2)
         (gen-many gen-identity
                   ", "
                   (list-head (list-tail form))
                   depth)
         (gen-many gen-statement
                   "\n"
                   (list-tail (list-tail form))
                   depth)
         (indent (+ depth 1))
         (indent depth))
      (return (flatten {table "function(" p ")\n" i1 b "\n" i2 "end"}))))

  ;;; plain function calls
  (= gen-call ; (list form, num): table num (atom | any)
     (function [form depth]
       (= (local l p)
          (gen-expression (list-head form) depth)
          (gen-many gen-expression ", " (list-tail form) depth))
       (return (flatten {table l "(" p ")"}))))

  ;;; invoke table methods
  (= gen-invoke ; (list form, num): table num (atom | any)
      (function [form depth]
       (= (local x m p)
          (gen-expression (list-head (list-tail form)) depth)
          (list-head (list-tail (list-tail form)))
          (gen-many gen-expression ", " (list-tail (list-tail form)) depth))
       (return (flatten {table x ":" m "(" p ")"}))))

  ;;; assigns value
  (= gen-set ; (list form, num): table num (atom | any)
     (function [form depth]
       (= (local x v)
          (gen-assign (list-head (list-tail form)) depth)
          (gen-many gen-expression ", " (list-tail (list-tail form)) depth))
       (return (flatten {table x " = " v}))))

  ;;; declare local variables, compatible with set
  (= gen-local ; (list form, num): table num (atom | any)
     (function [form depth]
       (= (local v) (gen-many gen-identity ", " (list-tail form) depth))
       (return (flatten {table "local " v}))))

  ;;; used by set to assign multiple values
  (= gen-comma ; (list form, num): table num (atom | any)
     (function [form depth]
       (return (flatten (gen-many gen-identity ", " (list-tail form) depth)))))

  ;;; creates a new lexical block, useful for let
  (= gen-do ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local b i1 i2)
         (gen-many gen-statement
                   {table "\n" (indent (+ depth 1))}
                   (list-tail form)
                   (+ depth 1))
         (indent (+ depth 1))
         (indent depth))
      (return (flatten {table "do\n" i1 b "\n" i2 "end"}))))

  ;;;
  (= gen-if ; (list form, num): table num (atom | any)
     (function [form depth]
      (return {table ""})))
      ; (if [cond ])


  ;;; returns value
  (= gen-return ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local p) (gen-many gen-expression "," (list-tail form) depth))
      (return (flatten {table "return " p}))))

  ;;; creates a while loop
  (= gen-while ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local x b i1 i2)
         (gen-expression (list-head (list-tail form)) depth)
         (gen-many gen-statement
                   {table "\n" (indent (+ depth 1))}
                   (list-tail (list-tail form))
                   (+ depth 1))
         (indent (+ depth 1))
         (indent depth))
      (return (flatten {table "while " x " do\n" i1 b "\n" i2 "end"}))))

  ;;;
  (= gen-repeat ; (list form, num): table num (atom | any)
     (function [form depth]))

  ;;; for loop
  (= gen-for ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local opts) (list-head (list-tail form)))
      (= (local iter walk) (list-head opts) (list-tail opts))
      (= (local step)  (list-head (list-tail walk)))
      (= (local i x t b i1 i2)
         (list-head iter)
         (gen-expression (list-head (list-tail iter)) depth)
         (gen-expression (list-head walk) depth)
         (gen-many gen-statement
                   {table "\n" (indent (+ depth 1))}
                   (list-tail (list-tail form))
                   (+ depth 1))
         (indent (+ depth 1))
         (indent depth))
      (if [step
           (= (local s)
              (gen-expression step depth))
           (return
            (flatten
              {table "for " i "=" x "," t "," s " do\n" i1 b "\n" i2 "end"}))])
      (return
        (flatten
          {table "for " i "=" x "," t " do\n" i1 b "\n" i2 "end"}))))

  ;;; for in loop
  (= gen-for-in ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local v x b  i1 i2)
        (gen-many gen-identity
                  ","
                   (list-head (list-tail form))
                   depth)
        (gen-many gen-expression
                  ","
                  (list-head (list-tail (list-tail form)))
                  depth)
        (gen-many gen-statement
                  {table "\n" (indent (+ depth 1))}
                  (list-tail (list-tail (list-tail form)))
                  (+ depth 1))
        (indent (+ depth 1))
        (indent depth))
      (return
        (flatten
          {table "for " v " in " x " do\n" i1 b "\n" i2 "end"}))))

  ;;; breaks loop
  (= gen-break ; (list form, num): table num (atom | any)
     (function [form depth]
      (return (list-head form))))

  ;;; creates a goto label
  (= gen-label ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local n) (list-head (list-tail form)))
      (return {table "::" n "::"})))

  ;;; goto statement
  (= gen-goto ; (list form, num): table num (atom | any)
     (function [form depth]
      (= (local n) (list-head (list-tail form)))
      (return {table "goto" n})))

  ;; valid expressions
  (= expressions
     {table (kv "+" gen-add) (kv "-" gen-sub) (kv "*" gen-mul) (kv "/" gen-div)
            (kv "%" gen-mod) (kv "^" gen-pow) (kv ".." gen-concat)
            (kv "==" gen-eq) (kv "~=" gen-neq) (kv "<" gen-lt) (kv "<=" gen-le)
            (kv ">" gen-gt) (kv ">=" gen-ge) (kv "and" gen-and)
            (kv "or" gen-or) (kv "not" gen-not) (kv "--" gen-unm)
            (kv "#" gen-len) (kv "parens" gen-parens) (kv "table" gen-table)
            (kv "." gen-dot) (kv "at" gen-at) (kv "function" gen-function)
            (kv ":" gen-invoke)})

  ;; valid statements
  (= statements
     {table (kv "local" gen-local) (kv "=" gen-set) (kv "do" gen-do)
            (kv "if" gen-if) (kv "return" gen-return) (kv "while" gen-while)
            (kv "repeat" gen-repeat) (kv "for" gen-for)
            (kv "for-in" gen-for-in) (kv "break" gen-break)
            (kv "label" gen-label) (kv "goto" gen-goto)})

  ;; table specific forms, basically any expression plus kv/xkv
  (= tables
     {table (kv "+" gen-add) (kv "-" gen-sub) (kv "*" gen-mul) (kv "/" gen-div)
            (kv "%" gen-mod) (kv "^" gen-pow) (kv ".." gen-concat)
            (kv "==" gen-eq) (kv "~=" gen-neq) (kv "<" gen-lt) (kv "<=" gen-le)
            (kv ">" gen-gt) (kv ">=" gen-ge) (kv "and" gen-and)
            (kv "or" gen-or) (kv "not" gen-not) (kv "--" gen-unm)
            (kv "#" gen-len) (kv "parens" gen-parens) (kv "table" gen-table)
            (kv "." gen-dot) (kv "at" gen-at) (kv "function" gen-function)
            (kv ":" gen-invoke) (kv "kv" gen-kv) (kv "xkv" gen-xkv)})

  ;; set specific forms
  (= assigns
     {table (kv "local" gen-local)
            (kv "many" gen-comma)
            (kv "." gen-dot)
            (kv "at" gen-at)})

  (= codegen
    (function [form depth]
     (= (local got) (gen-statement form (or depth 0)))
     (= (local out len) {table} 1)
     (for-in [n item] [(ipairs got)]
       (if [(is-atom item) (= (at out n) (atom-to-string item))]
           [else (= (at out n) (tostring item))])
       (= len n))
     (= (at out (+ len 1)) "\n")
     (return (table-concat out "")))))

;;; returns a macros table with default macros
(local macros-create) ; (): macros
(do
  ;;; returns true if string matches with a keyword
  (local is-keyword) ; (str): bool
  (do
    (= (local keywords)
      {table
        (kv "and" true)
        (kv "break" true)
        (kv "do" true)
        (kv "else" true)
        (kv "elseif" true)
        (kv "end" true)
        (kv "false" true)
        (kv "for" true)
        (kv "function" true)
        (kv "goto" true)
        (kv "if" true)
        (kv "in" true)
        (kv "local" true)
        (kv "nil" true)
        (kv "not" true)
        (kv "or" true)
        (kv "repeat" true)
        (kv "return" true)
        (kv "true" true)
        (kv "until" true)
        (kv "while" true)
        (kv "then" true)})

    (= is-keyword
      (function [str] (return (== (at keywords str) true)))))

  (= macros-create
     (function []
      (return {table}))))

;;; applies transforms to the source code
(= (local transform)
   (function [form transforms]
    ;;; TODO
    (return form)))

;;; returns a transforms array with default transforms for pre expansion phase
(local transforms-before-create) ; (): transforms
(do
  (= transforms-before-create
     (function []
      (return {table}))))

;;; returns a transforms array with default transforms for post expansion phase
(local transforms-after-create) ; (): transforms
(do
  (= transforms-after-create
     (function []
      (return {table}))))

;;; compiles a stream
(= (local compile-code) ; (code, opts): nil
   (function [code output opts]
    (= (local readers macros transforms-before transforms-after)
       (or (and opts (. opts readers)) (readers-create))
       (or (and opts (. opts macros)) (macros-create))
       (or (and opts (. opts transforms-before)) (transforms-before-create))
       (or (and opts (. opts transforms-after)) (transforms-after-create)))
    (while true
      (= (local form expanded?) (read code readers) false)
      (if [(== form nil) (break)])
      (= form (transform form transforms-before))
      (if [(== form nil) (goto skip)])
      (repeat
        (= (many expanded? form) (expand form macros))
        (if [(== form nil) (goto skip)])
        (if [expanded?
             (= form (transform form transforms-after))
             (if [(== form nil) (goto skip)])])
       until (not expanded?))
      (output (codegen form))
      (label skip))))

(= (local str) "(if [true (print 1)][false (print 2)][else (print 3)])")
(= (local print2) (function [str] ((. (. io stdout) write) (. io stdout) str)))
(= (local code) (code-from-string str))
(compile-code code print2)
(print2 "\n")
