; extends

(macro_invocation
  macro: [
    (scoped_identifier
      name: (_) @_macro_name)
    (identifier) @_macro_name
  ]
  (token_tree
    (raw_string_literal) @injection.content)
  (#match? @_macro_name "query(_as|_scalar|)")
  (#offset! @injection.content 0 3 0 -2)
  (#set! injection.language "sql")
  (#set! injection.include-children))

(macro_invocation
  macro: [
    (scoped_identifier
      name: (_) @_macro_name)
    (identifier) @_macro_name
  ]
  (token_tree
    (string_literal) @injection.content)
  (#match? @_macro_name "query(_as|_scalar|)")
  (#offset! @injection.content 0 1 0 0)
  (#set! injection.language "sql")
  (#set! injection.include-children))

(call_expression
  function: [
    (scoped_identifier
      name: (_) @_function_name)
    (identifier) @_function_name
  ]
  arguments: (arguments [
      (raw_string_literal
        (string_content) @injection.content)
      (string_literal
        (string_content) @injection.content)
  ])
  (#match? @_function_name "query(_as|_scalar|)")
  (#set! injection.language "sql"))
