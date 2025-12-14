return {
  desc = "Force task to be non-ephemeral",
  editable = false,
  serializable = false,
  constructor = function(_)
    return {
      on_pre_start = function(_, task)
        task.ephemeral = false
      end,
    }
  end,
}
