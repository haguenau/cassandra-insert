# cassandra-insert

cassandra-insert is a command line tool to bulk-insert records into a
ScyllaDB or Cassandra database. Input is in TSV format, and,
additionally, constant-valued columns can be specified on the command
line.

## Example

With a table defined as follows in keyspace `foo`:

```sql
CREATE TABLE things (
  id BIGINT PRIMARY KEY,
  name TEXT,
  count BIGINT
)
```

(The keyspace might have been created as `CREATE KEYSPACE foo WITH
replication = {'class': 'SimpleStrategy', 'replication_factor' : 1}`.)

And an input `things.tsv` as:

```tsv
1	Foo
2	Bar
4	Baz
```

The command:

```bash
cassandra-insert --db foo --table=things \
  --const=count:auto=32 \
  --header=id:auto,name:auto \
  <things.tsv
```

Would result in the table getting populated as:


```term
cqlsh:foo> SELECT * FROM things;

 id | count | name
----+-------+------
  2 |    32 |  Bar
  4 |    32 |  Baz
  1 |    32 |  Foo

(3 rows)
```

Note that:

* The `--const` option was used to mention that column `count` should
  always be set to value `32`, with type to be determined
  automatically (`auto`) at insertion time, and indeed all rows
  inserted by the command have value `32` for `count`;

* `--header` applies a header to the TSV data: in this case, two
  columns `id` and `name`, in this order;

* the input is simply piped into `cassandra-insert`.

## Handy options

* `--print-json` makes the script print some metrics in JSON format,
  for example:

    ```json
    {
      "async": 128,
      "bad_recs": 0,
      "db": "foo",
      "effective_wps": 2,
      "jobs": 32,
      "max_connections": 64,
      "recs_in": 3,
      "recs_out": 3,
      "seconds_slept": 0,
      "seconds_slept_children": 0,
      "seconds_total": 1.45,
      "seconds_total_children": 2.68,
      "table": "things",
      "ttl": 86400,
      "unix_time": 1601000000,
      "wps_throttle": 32000,
      "write_failures": 0
    }
    ```

    In actual usage, the JSON text is not pretty-printed; rather it is
    printed on a single line. `--write-json` is similar, except it
    writes to a named file instead of standard output.

* `--print-kv` prints information similar to `--print-json`, but in a
  format that may be simpler for some monitoring tools to parse: lines
  each made of a key, a space, and a value, for example:

    ```text
    async 128
    bad_recs 0
    db foo
    effective_wps 1
    jobs 32
    max_connections 64
    recs_in 3
    recs_out 3
    seconds_slept 0
    seconds_slept_children 0
    seconds_total 1.53
    seconds_total_children 2.53
    table things
    ttl 86400
    unix_time 1601000000
    wps_throttle 32000
    write_failures 0
    ```

* `--nodes=host,...` can be used to set a list of seed nodes
  (overriding that from `conf/cassandra-insert.json`; a useful value
  may be `--nodes 172.17.0.2` if running ScyllaDB from the official
  Docker image as `docker run --name scylla --hostname scylla
  scylladb/scylla`; in which case, run `docker exec -it scylla
  nodetool status` to find out the list of nodes).

## Performance

When this tool was first written, it was an attempt at applying best
practices for writing to a ScyllaDB cluster with high throughput:
numerous writers, async groups. This may be completely inadequate for
Cassandra clusters.

This program has successfully been used in production to quickly push
batches of millions of records to a small ScyllaDB cluster. Option
`--throttle-wps=N` may be used to limit insertions to _N_ per second,
in order to avoid affecting concurrent reads too much.
