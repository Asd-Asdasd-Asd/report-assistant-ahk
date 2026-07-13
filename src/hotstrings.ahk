:*?:;red::
{
    InsertRedFigureTextAndRestoreState()
}

:*?:;fzg::
{
    SendText("放射性摄取增高，SUVmax约")
    operation := InsertRedFigureTextAndRestoreState()
    if operation.ok
        Send("{Left 4}")
}

:*?:;fwj::
{
    SendText("放射性摄取未见明显增高")
    InsertRedFigureTextAndRestoreState()
}

:*?:;fjd::
{
    SendText("放射性摄取降低")
    InsertRedFigureTextAndRestoreState()
}

:*?:;cmx::
{
    SendText("cm×cm")
    Send("{Left 2}")
}
