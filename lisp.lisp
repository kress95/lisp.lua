;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high priority:
;;
;; - add codegen
;; - add error reporting
;;
;; medium priority:
;;
;; - add transforms
;; - add quasiquote/unquote/unquote-splicing support
;; - add compatibility layer transform for luajit 5.1 mode
;;
;; low priority:
;;
;; - find a better name for box
;; - add 'everything is an expression' transform
;; - add sourcemapped error reporting for runtime
;; - break compatibility with `#` and `-` readers
;; - add a runtime library transform
;;
;; it will probably need 2kloc :T
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; blocks evil global get/set
(setmetatable _G
  {table
    (kv __index
      (function [_ k]
        (error (.. "variable " k " is not declared") 2))
     (kv __newindex
      (function [_ k v]
        (error (.. "declaring global " k " to " (tostring v)) 2))))})

;;;;
;;;; localized functions
;;;;

(= (local string-gsub) (. string gsub))
(= (local string-sub) (. string sub))
(= (local string-byte) (. string byte))
(= (local string-char) (. string char))
(= (local string-find) (. string find))
(= (local string-upper) (. string upper))
(= (local string-lower) (. string lower))
(= (local string-format) (. string format))
(= (local table-concat) (. table concat))
(= (local debug-getinfo) (. debug getinfo))
(= (local io-open) (. io open))
(= (local io-read) (. io read))
(= (local io-close) (. io close))

;;;;
;;;; helper functions
;;;;

;;; prints using inspect (if available)
(local puts)
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

;;; throws a previously catched error
(= (local error2)
   (function [msg lvl]
    (if [(== (type msg) "string")
         (= msg (string-gsub msg ".-%.lua%:%d+%:%s" ""))])
    (= lvl (+ (or lvl 1) 1))
    (error msg lvl)))

;;; checks if a string is a keyword
(local is-keyword)
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

;;; try to turn a string into a valid lua identifier, may fail if the string
;;; conflicts with a lua keyword
(local to-identifier)
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

;;; flattens a table
(local flatten)
(= flatten
   (function [arr]
    (= (local buf idx len) {table} 0 (# arr))
    (for [(i 1) len]
      (= (local item) (at arr i))
      (if [(and (== (type item) "table") (== (getmetatable item) nil))
           (= (local arr2) (flatten item))
           (= (local len2) (# arr2))
           (for [(i 1) len2]
            (= idx (+ idx 1))
            (= (at buf idx) (at arr2 i)))]
          [else
           (= idx (+ idx 1))
           (= (at buf idx) item)]))
    (return buf)))

;;;;
;;;; compiler types
;;;;

;;;; immutable sourcemap type
(local sourcemap-create
       sourcemap-merge
       is-sourcemap
       sourcemap-source
       sourcemap-from-line
       sourcemap-to-line
       sourcemap-from-column
       sourcemap-to-column)
(do
  (= (local sourcemap) {table})

  ;;;;
  ;;;; build
  ;;;;

  (= sourcemap-create
     (function [source line column]
      (return
        (setmetatable
          {table (kv source source)
                 (kv from-line line)
                 (kv to-line line)
                 (kv from-column column)
                 (kv to-column column)}
          sourcemap))))

  (= sourcemap-merge
     (function [sourcemap-from sourcemap-to]
      ;; TODO: add validation
      (= (local from-line from-column)
         (sourcemap-from-line sourcemap-from)
         (sourcemap-from-column sourcemap-from))
      (= (local to-line to-column)
         (sourcemap-to-line sourcemap-to)
         (sourcemap-to-column sourcemap-to))
      (return
        (setmetatable
          {table (kv source (sourcemap-source sourcemap))
                 (kv from-line from-line)
                 (kv to-line to-line)
                 (kv from-column from-column)
                 (kv to-column to-column)}
          sourcemap))))

  ;;;;
  ;;;; query
  ;;;;

  (= is-sourcemap
     (function [maybe-self] (return (== (getmetatable maybe-self) sourcemap))))

  (= sourcemap-source
     (function [self] (return (. self source))))

  (= sourcemap-from-line
     (function [self] (return (. self from-line))))

  (= sourcemap-to-line
     (function [self] (return (. self to-line))))

  (= sourcemap-from-column
     (function [self] (return (. self from-column))))

  (= sourcemap-to-column
     (function [self] (return (. self to-column)))))

;;;; immutable form type
(local form-create-empty
       form-create-with
       form-cons
       form-reverse
       is-form
       form-is-empty
       form-head
       form-tail
       form-split
       form-to-table
       form-unpack)
(do
  (= (local form) {table})

  ;;;;
  ;;;; build
  ;;;;

  (= form-create-empty
     (function [] (return (setmetatable {table} form))))

  (= form-create-with
     (function [this ...]
      (if [(~= this nil)
           (return (setmetatable {table this (form-create-with ...)} form))]
          [else (return (setmetatable {table} form))])))

  (= form-cons
     (function [item other] (return (setmetatable {table item other} form))))

  (= form-reverse
     (function [self]
      (= (local other) (form-create-empty))
      (while (at self 2)
        (= other (form-cons (at self 1) other))
        (= self (at self 2)))
      (return other)))

  ;;;;
  ;;;; query
  ;;;;

  ;;;; helpers

  (= (local next)
     (function [_ self] (if [self (return (at self 2) (at self 1))])))

  ;;;; implementation

  (= is-form
     (function [maybe-self] (return (== (getmetatable maybe-self) form))))

  (= form-is-empty
     (function [self]
      (return (and (== (at self 1) nil) (== (at self 2) nil)))))

  (= form-head
     (function [self] (return (at self 1))))

  (= form-tail
     (function [self] (return (at self 2))))

  (= form-split
     (function [self at]
      (= (local left idx right) {table} 0 self)
      (for-in [tail head] [(pairs self)]
        (if [(> idx at) (break)])
        (= idx (+ idx 1))
        (= (at left idx) head)
        (= right tail))
      (return (form-create-with (unpack left)) right)))

  (= form-to-table
     (function [self]
      (= (local arr idx) {table} 0)
      (while (at self 2)
        (= idx (+ idx 1))
        (= (at arr idx) (at self 1))
        (= self (at self 2)))
      (return arr)))

  (= form-unpack
     (function [self] (return (unpack (form-to-table self)))))

  (= (. form __len)
     (function [self]
      (= (local len) 0)
      (while (at self 2)
        (= len (+ len 1))
        (= self (at self 2)))
      (return len)))

  (= (. form __pairs)
     (function [self] (return next self self)))

  ;;; form/__tostring
  (= (. form __tostring)
     (function [self]
       (= (local out idx) {table "("} 1)
       (for-in [tail head] [(pairs self)]
        (= idx (+ idx 1))
        (= (at out idx) (tostring head))
        (if [(at tail 2)
             (= idx (+ idx 1))
             (= (at out idx) " ")]))
      (= (at out (+ idx 1)) ")")
      (return (table-concat out "")))))

;;;; immutable box type
(local box-create-value
       box-create-atom
       box-to-literal
       is-box
       box-is-atom
       box-is-literal
       box-content
       box-sourcemap)
(do
  (= (local box) {table})

  ;;;;
  ;;;; data stores
  ;;;;

  ;; stores box's content
  (= (local content-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;; stores box's atomicity
  (= (local atom-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;; stores box's literalness
  (= (local literal-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;; stores box's sourcemap information
  (= (local sourcemap-store)
     (setmetatable {table} {table (kv __mode "k")}))

  ;;;;
  ;;;; build
  ;;;;

  (= box-create-value
     (function [value sourcemap]
      (= (local self) (setmetatable {table} box))
      (= (at content-store self) value)
      (= (at sourcemap-store self) sourcemap)
      (return self)))

  (= box-create-atom
     (function [value sourcemap]
      (= (local self) (setmetatable {table} box))
      (= (at content-store self) value)
      (= (at atom-store self) true)
      (= (at sourcemap-store self) sourcemap)
      (return self)))

  (= box-to-literal
     (function [self]
      (if [(box-is-atom self)
           (= (local new-self)
              (box-create-atom (box-content self) (box-sourcemap self)))
           (= (at literal-store new-self) true)
           (return new-self)]
          [else (error "only atomic boxes can be literals")])))

  ;;;
  ;;; query
  ;;;

  (= is-box
     (function [maybe-self] (return (== (getmetatable maybe-self) box))))

  (= box-is-atom
     (function [self]
      (return (and (is-box self) (== (at atom-store self) true)))))

  (= box-is-literal
     (function [self] (return (== (at literal-store self) true))))

  (= box-content
     (function [self] (return (at content-store self))))

  (= box-sourcemap
     (function [self] (return (at sourcemap-store self))))

  (= (. box __tostring)
     (function [self]
      (= (local content) (at content-store self))
      (= (local ok msg) (pcall tostring content))
      (if [(not ok) (error2 msg 2)])
      (if [(box-is-literal self) (return msg)])
      (if [(box-is-atom self)
           (= (many ok msg) (to-identifier msg))
           (if [(not ok) (error msg 2)])
           (return msg)])
      (if [(== (type content) "string") (return (.. "\"" msg "\""))]
          [else (return msg)]))))

;;;; mutable stream type
(local stream-create
       stream-from-string
       stream-from-file
       is-stream
       stream-move
       stream-next)
(do
  (= (local stream) {table})

  ;;;;
  ;;;; build
  ;;;;

  ;;;; helpers

  (= (local from-file)
     (function [path]
      (= (local file) (assert (io-open path "r")))
      (= (local closed) false)
      (return
        (function []
          (if [closed (return)])
          (= (local char) (io-read file 1))
          (if [char (return (string-byte char 1))]
              [else
               (io-close file)
               (= closed true)]))
        file)))

  (= (local from-string)
     (function [str]
      (= (local idx) 0)
      (= (local len) (# str))
      (return
        (function []
          (if [(>= idx len) (return)])
          (= idx (+ idx 1))
          (return (string-byte str idx))))))

  ;;;; implementation

  (= stream-create
     (function [get-char source]
        (return (setmetatable {table (kv get-char get-char)
                                     (kv source source)
                                     (kv index 0)
                                     (kv cache {table})
                                     (kv cache-length 0)}
                              stream))))

  (= stream-from-file
     (function [path]
      (= (local get-char file) (from-file path))
      (return (stream-create get-char path) file)))

  (= stream-from-string
     (function [str source]
      (return (stream-create (from-string str) (or source "in-memory")))))

  ;;;;
  ;;;; query
  ;;;;

  ;;;; helpers

  ;;; returns last line/column for last cached entry
  (= (local get-line-column)
     (function [self]
      (= (local cached) (at (. self cache) (. self length)))
      (if [(not cached) (return 1 0)])
      (= (local sourcemap) (. cached sourcemap))
      (return (sourcemap-to-line sourcemap) (sourcemap-to-column  sourcemap))))

  ;;; returns a new sourcemap for the new character
  (= (local get-sourcemap)
     (function [self char]
      (= (local line column) (get-line-column self))
      (if [(== char 10)
           (= line (+ line 1))
           (= column 1)]
          [(~= char 13)
           (= column (+ column 1))])
      (return (sourcemap-create (. self source) line column))))

  ;;; push following character to cache
  (= (local push-char)
     (function [self char]
      (= (local length) (+ (. self cache-length) 1))
      (= (local sourcemap) (get-sourcemap self char))
      (= (local cached) {table (kv char char) (kv sourcemap sourcemap)})
      (= (at (. self cache) length) cached)
      (= (. self cache-length) length)
      (= (. self index) length)
      (return char sourcemap)))

  ;;;; implementation

  (= is-stream
     (function [maybe-self]
      (return (== (getmetatable maybe-self) stream))))

  (= stream-move
     (function [self offset]
      (= (local index) (+ (. self index) offset))
      (= (local length) (. self cache-length))
      (if [(> index length)
           (= (local diff) (- index length))
           (for [(idx 1) diff] (stream-next self))]
          [else
            (if [(< index 0) (= index 0)])
            (= (. self index) index)])
      (return self)))

  (= stream-next
     (function [self]
      (= (local index) (. self index))
      (if [(< index (. self cache-length))
           (= index (+ index 1))
           (= (. self index) index)
           (= (local cached) (at (. self cache) index))
           (return (. cached char) (. cached sourcemap))]
          [else
           (= (local char) ((. self get-char)))
           (if [char (return (push-char self char))])])))

  (= (. stream __pairs)
     (function [self]
      (return stream-next self))))

;;; gets content of any type
(= (local any-content)
   (function [any]
    (if [(is-box any) (return (box-content any))]
        [else (return any)])))

;;;;
;;;; reader
;;;;

(= (local read)
   (function [stream readers]
    (for-in [char sourcemap] [(pairs stream)]
      (= (local reader) (at readers char))
      (if [reader
           (= (local result) (reader readers stream char sourcemap))
           (if [result (return result)])]
          [else
            (= (local buf len) {table char} 1)
            (= (local init) sourcemap)
            (= (local term) sourcemap)
            (for-in [char sourcemap] [(pairs stream)]
              (if [(at readers char)
                   (stream-move stream (- 1))
                   (break)])
              (= len (+ len 1))
              (= (at buf len) char)
              (= term sourcemap))
            (return
              (box-create-atom
                (string-char (unpack buf))
                (sourcemap-merge init term)))]))))

;;;;
;;;; readers
;;;;

(local readers-create)
(do
  (= (local char-ht) 9)
  (= (local char-lf) 10)
  (= (local char-cr) 13)
  (= (local char-space) 32)
  (= (local char-quotation-mark) 34)
  (= (local char-apostrophe) 39)
  (= (local char-opened-parens) 40)
  (= (local char-closed-parens) 41)
  (= (local char-comma) 44)
  (= (local char-hyphen) 45)
  (= (local char-semicolon) 59)
  (= (local char-at-sign) 64)
  (= (local char-opened-brackets) 91)
  (= (local char-backslash) 92)
  (= (local char-closed-brackets) 93)
  (= (local char-grave-accent) 96)
  (= (local char-opened-braces) 123)
  (= (local char-closed-braces) 125)

  ;;;;
  ;;;; build
  ;;;;

  ;;;; helpers

  ;;; ignores a single char
  (= (local ignore-char-reader) (function [] (return)))

  ;;; ignores a chars until a newline
  (= (local comment-reader)
     (function [readers stream char sourcemap]
      (for-in [char] [(pairs stream)]
        (if [(== char char-lf)
             (stream-move stream (- 1))
             (break)]))))

  ;;; reads a negative number
  ;; TODO: create the reader

  ;;; reads a string
  (= (local string-reader)
     (function [readers stream char sourcemap]
      (= (local buf len) {table} 0)
      (= (local prev) char-quotation-mark)
      (= (local init) sourcemap)
      (for-in [char term] [(pairs stream)]
        (if [(and (== char char-quotation-mark) (~= prev char-backslash))
             (return (box-create-value (string-char (unpack buf))
                                       (sourcemap-merge init term)))])
        (= len (+ len 1))
        (= (at buf len) char)
        (= prev char))
      (error "unclosed string")))

  ;;; reads quote
  (= (local quote-reader)
     (function [readers stream char sourcemap]
      (= (local atom) (box-create-atom "quote" sourcemap))
      (= (local item) (read stream readers))
      (return (form-create-with atom item))))

  ;;; reads quasiquote
  (= (local quasiquote-reader)
     (function [readers stream char sourcemap]
      (= (local atom) (box-create-atom "quasiquote" sourcemap))
      (= (local item) (read stream readers))
      (return (form-create-with atom item))))

  ;;; reads unquote and unquote-splicing
  (= (local unquote-and-unquote-splicing-reader)
     (function [readers stream char sourcemap]
      (if [(== (stream-next stream) char-at-sign)
           (= (local atom) (box-create-atom "unquote-splicing" sourcemap))
           (= (local item) (read stream readers))
           (return (form-create-with atom item))]
          [else
           (stream-move stream (- 1))
           (= (local atom) (box-create-atom "unquote" sourcemap))
           (= (local item) (read stream readers))
           (return (form-create-with atom item))])))

  ;;; returns readers for opened and closed forms
  (= (local create-form-reader)
     (function [open-char close-char]
      (= (local opened)
         (function [readers stream char sourcemap]
          (= (local form) (form-create-empty))
          (for-in [char term] [(pairs stream)]
            (if [(== char close-char)
                 (return (form-reverse form))])
            (= (local reader) (at readers char))
            (if [reader
                 (= (local result) (reader readers stream char sourcemap))
                 (if [(~= result nil) (= form (form-cons result form))])]
                [else
                 (stream-move stream (- 1))
                 (= form (form-cons (read stream readers) form))]))
          (error "unmatched delimiter")))
      (= (local closed)
         (function [readers stream char sourcemap]
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

  ;;;; implementation

  ;;; returns a readers table
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

;;;;
;;;; parser
;;;;

(= (local parse)
   (function [stream readers]
    (= (local form) (form-create-empty))
    (while true
      (= (local item) (read stream readers))
      (if [item (= form (form-cons item form))]
          [else (break)]))
    (return form)))

;;;;
;;;; expander
;;;;

(local expand-ap-once
       expand-ap
       expand)
(do
  (= expand-ap-once
     (function [form macros]
      (= (local head) (form-head form))
      (if [(not (is-box head)) (return false form)])
      (= (local macro) (at macros (box-content head)))
      (= (local result changed?) form false)
      (if [macro
           (= result (macro (form-unpack (form-tail form))))
           (= changed? true)])
      (if [(not (is-form result)) (return changed? result)])
      (= (local buf idx) {table} 0)
      (for-in [tail head] [(pairs (form-tail result))]
        (= idx (+ idx 1))
        (= (local change? item) (expand-ap-once head macros))
        (= changed? (or changed? change?))
        (= (at buf idx) item))
      (return changed? (form-create-with (form-head result) (unpack buf)))))

  (= expand-ap
     (function [dong macros]
      (local expanded?)
      (repeat
        (= (many expanded? dong) (expand-ap-once dong macros))
       until (not expanded?))
      (return dong)))

  (= expand
     (function [ast macros]
      (= (local out) (form-create-empty))
      (for-in [tail head] [(pairs ast)]
        (= out (form-cons (expand-ap head macros) out)))
      (return (form-reverse out)))))

;;;;
;;;; transforms
;;;;

(local transforms-create)
(do) ; TODO 3rd (will probably use 100loc)

;;;;
;;;; code generator
;;;;

(local codegen)
(do
  ;; identation sign
  (= (local indent) {table})
  ; (= (local indents) {table})

  ; (for [(i 0) 999]
  ;   (= (local step) {table})
  ;   (for [(j 0) i] (= (at step j) indent))
  ;   (= (at indents i) step))

  ;;;; helpers

  ; ;;; separate with commas
  ; (= (local sep-with-commas)
  ;    (function []
  ;     (return ", ")))

  ;;; separate with lines
  (= (local sep-with-lines)
     (function [depth]
      (= (local out) {table "\n"})
      (= depth (+ depth 1))
      (for [(i 2) depth] (= (at out i) indent))
      (return out)))

  ; ;;; separate with lines and commas
  ; (= (local sep-with-comma-and-lines)
  ;    (function [depth]
  ;     (= (local out) {table ",\n"})
  ;     (= depth (+ depth 1))
  ;     (for [(i 2) depth] (= (at out i) indent))
  ;     (return out)))

  ; ;;; concatenate atom form
  ; (= (local concat-atom-form)
  ;    (function [sep form depth]))

  ;;; generated and concatenate form
  (= (local concat-gen-form)
     (function [gen sep forms depth]
      (= (local out idx) {table} 0)
      (for-in [tail head] [(pairs forms)]
        (= (local result) (gen head depth))
        (if [result
             (= idx (+ idx 1))
             (= (at out idx) result)
             (if [(not (form-is-empty tail))
                  (= idx (+ idx 1))
                  (= (at out idx) (sep depth))])]))
      (return out)))

  ;; generic form generators
  (local xpr stm tbl set)

  ;;;; specific generators

  (= (local gen-add)
     (function [form depth] (print "gen-add is not implemented yet")))

  (= (local gen-sub-unm)
     (function [form depth] (print "gen-sub-unm is not implemented yet")))

  (= (local gen-mul)
     (function [form depth] (print "gen-mul is not implemented yet")))

  (= (local gen-div)
     (function [form depth] (print "gen-div is not implemented yet")))

  (= (local gen-mod)
     (function [form depth] (print "gen-mod is not implemented yet")))

  (= (local gen-pow)
     (function [form depth] (print "gen-pow is not implemented yet")))

  (= (local gen-concat)
     (function [form depth] (print "gen-concat is not implemented yet")))

  (= (local gen-eq)
     (function [form depth] (print "gen-eq is not implemented yet")))

  (= (local gen-lt)
     (function [form depth] (print "gen-lt is not implemented yet")))

  (= (local gen-lt)
     (function [form depth] (print "gen-lt is not implemented yet")))

  (= (local gen-gt)
     (function [form depth] (print "gen-gt is not implemented yet")))

  (= (local gen-ge)
     (function [form depth] (print "gen-ge is not implemented yet")))

  (= (local gen-neq)
     (function [form depth] (print "gen-neq is not implemented yet")))

  (= (local gen-and)
     (function [form depth] (print "gen-and is not implemented yet")))

  (= (local gen-or)
     (function [form depth] (print "gen-or is not implemented yet")))

  (= (local gen-not)
     (function [form depth] (print "gen-not is not implemented yet")))

  (= (local gen-table)
     (function [form depth] (print "gen-table is not implemented yet")))

  (= (local gen-function)
     (function [form depth] (print "gen-function is not implemented yet")))

  (= (local gen-dot)
     (function [form depth] (print "gen-dot is not implemented yet")))

  (= (local gen-at)
     (function [form depth] (print "gen-at is not implemented yet")))

  (= (local gen-invoke)
     (function [form depth] (print "gen-invoke is not implemented yet")))

  (= (local gen-do)
     (function [form depth]
      (return
        {table
          (box-to-literal (form-head form))
          (concat-gen-form stm sep-with-lines (form-tail form) (+ depth 1))
          "end"})))

  (= (local gen-set)
     (function [form depth] (print "gen-set is not implemented yet")))

  (= (local gen-local)
     (function [form depth] (print "gen-local is not implemented yet")))

  (= (local gen-return)
     (function [form depth] (print "gen-return is not implemented yet")))

  (= (local gen-while)
     (function [form depth] (print "gen-while is not implemented yet")))

  (= (local gen-repeat)
     (function [form depth] (print "gen-repeat is not implemented yet")))

  (= (local gen-break)
     (function [form depth] (print "gen-break is not implemented yet")))

  (= (local gen-label)
     (function [form depth] (print "gen-label is not implemented yet")))

  (= (local gen-goto)
     (function [form depth] (print "gen-goto is not implemented yet")))

  (= (local gen-for)
     (function [form depth] (print "gen-for is not implemented yet")))

  (= (local gen-for-in)
     (function [form depth] (print "gen-for-in is not implemented yet")))

  (= (local gen-if)
     (function [form depth] (print "gen-if is not implemented yet")))

  (= (local gen-kv)
     (function [form depth] (print "gen-kv is not implemented yet")))

  (= (local gen-xkv)
     (function [form depth] (print "gen-xkv is not implemented yet")))

  (= (local gen-comma)
     (function [form depth] (print "gen-comma is not implemented yet")))

  (= (local gen-call)
     (function [form depth] (print "gen-call is not implemented yet")))

  ;;;; generator scope

  ;; expression scope
  (= (local xpr-scope)
     {table
      (kv "+" gen-add)
      (kv "-" gen-sub-unm)
      (kv "*" gen-mul)
      (kv "/" gen-div)
      (kv "%" gen-mod)
      (kv "^" gen-pow)
      (kv ".." gen-concat)
      (kv "==" gen-eq)
      (kv "<" gen-lt)
      (kv "<=" gen-lt)
      (kv ">" gen-gt)
      (kv ">=" gen-ge)
      (kv "~=" gen-neq)
      (kv "and" gen-and)
      (kv "or" gen-or)
      (kv "not" gen-not)
      (kv "table" gen-table)
      (kv "function" gen-function)
      (kv "." gen-dot)
      (kv "at" gen-at)
      (kv ":" gen-invoke)})

  ;; statement scope
  (= (local stm-scope)
     {table
      (kv "do" gen-do)
      (kv "=" gen-set)
      (kv "local" gen-local)
      (kv "return" gen-return)
      (kv "while" gen-while)
      (kv "repeat" gen-repeat)
      (kv "break" gen-break)
      (kv "label" gen-label)
      (kv "goto" gen-goto)
      (kv "for" gen-for)
      (kv "for-in" gen-for-in)
      (kv "if" gen-if)
      (kv ":" gen-invoke)})

  ;; table scope
  (= (local tbl-scope)
     {table
      (kv "kv" gen-kv)
      (kv "xkv" gen-xkv)})

  ;; set scope
  (= (local set-scope)
     {table
      (kv "local" gen-local)
      (kv "many" gen-comma)})

  (= (local fallback-to-gen-call)
     (function [scope]
      (return
        (function [form depth]
          (= (local head) (form-head form))
          (if [(not (box-is-atom head)) (error "wtf not an atom")])
          (= (local name) (box-content head))
          (= (local generator) (at scope name))
          (if [generator (return (generator form depth))]
              [else (return (gen-call form depth))])))))

  (= xpr (fallback-to-gen-call xpr-scope))
  (= stm (fallback-to-gen-call stm-scope))

  (= (local get-indent)
     (function [size]
      (= (local buf) {table})
      (for [(i 1) size]
        (= (at buf i) " "))
      (return (table-concat buf ""))))

  ;;;; implementation

  (= codegen
     (function [forms indent-size depth]
      ;; TODO: generate sourcemap
      (= (local indent-str) (get-indent (or indent-size 3)))
      (= (local buf)
         (flatten (concat-gen-form stm sep-with-lines forms (or depth 0))))
      (= (local len) (# buf))
      (for-in [i item] [(ipairs buf)]
        (if [(is-box buf) (= (at buf i) (tostring item))]
            [(== item indent) (= (at buf i) indent-str)]
            [else (= (at buf i) (tostring item))]))
      (return (table-concat buf "")))))

;;;;
;;;; macros
;;;;

(local macros-create)
(do ; will probably use 100loc
  (= (local macro-wow)
     (function [...]
       (return (form-create-with (box-create-atom "waw") ...))))

  (= (local macro-waw)
     (function [...]
       (return (form-create-with (box-create-atom "do") ...))))

  (= macros-create
     (function []
      (return
        {table
          (kv "wow" macro-wow)
          (kv "waw" macro-waw)}))))

;;;;
;;;; compiler
;;;;

(local compile)
(do) ; TODO 2nd

(= (local source) "(wow (print \"hello world\"))(wow (print \"hello world\"))")
(= (local stream) (stream-from-string source))
(= (local readers) (readers-create))
(= (local form) (parse stream readers))
(print "old:" form)
(= form (expand form (macros-create)))
(print "exp:" form)
(print (codegen form))
