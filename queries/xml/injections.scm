;; MyBatis XML SQL injections for tree-sitter-xml grammar
;; Nodes: element -> STag/ETag, Name, content, CharData, cdata_section

; Inject SQL inside <select>/<insert>/<update>/<delete>/<sql>
(element
  (STag
    (Name) @_name
  )
  (content) @injection.content
  (ETag
    (Name) @_end
  )
  (#any-of? @_name "select" "insert" "update" "delete" "sql")
  (#eq? @_name @_end)
  (#set! injection.language "sql")
  (#set! injection.include-children)
)

