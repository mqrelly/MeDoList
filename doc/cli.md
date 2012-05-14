CLI syntax
==========

Basic operations:
- Add task
- Start task
- Stop task
- Tag task
- Change task status (suspend,resume,done,cancel)
- Filter and list tasks

'add' syntax:

    $ mld add <task-name> [-t <tag-list>] [-m <status>] [-S|--start]

'list' syntax:

    $ mdl list

'tag' syntax:

    $ mdl tag <task-ref> <tag-list>

<task-ref>:= #<task-id>|<task-name>|#<last-referenced-number>
