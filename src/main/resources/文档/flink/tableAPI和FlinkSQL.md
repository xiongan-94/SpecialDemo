## demo

### (0) 依赖

```xml
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-connector-kafka-0.11_2.12</artifactId>
    <version>1.10.1</version>
</dependency>
<dependency>
    <groupId>redis.clients</groupId>
    <artifactId>jedis</artifactId>
    <version>2.9.3</version>
</dependency>
<dependency>
    <groupId>org.apache.bahir</groupId>
    <artifactId>flink-connector-redis_2.11</artifactId>
    <version>1.0</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-connector-elasticsearch6_2.12</artifactId>
    <version>1.10.1</version>
</dependency>
<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <version>5.1.44</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-statebackend-rocksdb_2.12</artifactId>
    <version>1.10.1</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-table-planner_2.12</artifactId>
    <version>1.10.1</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-table-api-java-bridge_2.12</artifactId>
    <version>1.10.1</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-table-planner-blink_2.12</artifactId>
    <version>1.10.1</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-csv</artifactId>
    <version>1.10.1</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-json</artifactId>
    <version>1.10.1</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-jdbc_2.12</artifactId>
    <version>1.10.1</version>
</dependency>
```

### (1) 代码

```java
//1.创建执行环境
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
env.setParallelism(1);

//2.读取文本数据创建流并转换为JavaBean
SingleOutputStreamOperator<SensorReading> sensorDS = env.readTextFile("sensor")
        .map(line -> {
            String[] fields = line.split(",");
            return new SensorReading(fields[0], Long.parseLong(fields[1]), Double.parseDouble(fields[2]));
        });

//3.创建TableAPI FlinkSQL 的执行环境
StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);

//4.使用Table执行环境将流转换为Table
tableEnv.createTemporaryView("sensor", sensorDS);

//5.TableAPI
Table table = tableEnv.from("sensor");
Table tableResult = table.select("id,temp").where("id='sensor_1'");

//6.SQL
Table sqlResult = tableEnv.sqlQuery("select id,temp from sensor where id ='sensor_1'");

//7.将结果数据打印
tableEnv.toAppendStream(tableResult, Row.class).print("tableResult");
tableEnv.toAppendStream(sqlResult, Row.class).print("sqlResult");

//8.执行
env.execute();
```

## env创建

1.10版本的flink不建议使用Blink

默认使用的老版本的批处理

```java
//1.基于老版本的流式处理环境
EnvironmentSettings settings = EnvironmentSettings.newInstance()
        .useOldPlanner()      // 使用老版本planner
        .inStreamingMode()    // 流处理模式
        .build();
StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env, settings);

// 使用流的环境直接能够创建出流的Table环境
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
 StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);

//2.基于老版本的批处理环境
ExecutionEnvironment batchEnv = ExecutionEnvironment.getExecutionEnvironment();
BatchTableEnvironment batchTableEnv = BatchTableEnvironment.create(batchEnv);

//3.基于新版本的流式处理环境
EnvironmentSettings bsSettings = EnvironmentSettings.newInstance()
        .useBlinkPlanner()
        .inStreamingMode()
        .build();
StreamTableEnvironment bsTableEnv = StreamTableEnvironment.create(env, bsSettings);

//4.基于新版本的批处理环境
EnvironmentSettings bbSettings = EnvironmentSettings.newInstance()
        .useBlinkPlanner()
        .inBatchMode()
        .build();
TableEnvironment bbTableEnv = TableEnvironment.create(bbSettings);
```

## source

### (1) source-File

```java
//定义文件连接器
tableEnv.connect(new FileSystem()
                 // 设置路径
                 .path("sensor"))
    // 添加文件格式化器,Csv表示使用,分隔
        .withFormat(new OldCsv())
    // 填入字段
        .withSchema(new Schema()
                .field("id", DataTypes.STRING())
                .field("ts", DataTypes.BIGINT())
                .field("temp", DataTypes.DOUBLE()))
    // 创建表并填入名称
        .createTemporaryTable("fileInput");

// 使用source创建table
Table table = tableEnv.from("fileInput");
```

### (2) source-Kafka

```java
tableEnv.connect(new Kafka()
                // 主题
                .topic("flinkSourceTest")
                // 版本
                .version("0.11")
                // 添加参数 连接和消费者组
                .property(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "hadoop102:9092")
                .property(ConsumerConfig.GROUP_ID_CONFIG, "testKafkaSource"))
                // 确认读取参数的类型,文件类型不对会报错
                //.withFormat(new Csv())
                .withFormat(new Json())
                .withSchema(new Schema()
                        .field("id", DataTypes.STRING())
                        .field("ts", DataTypes.BIGINT())
                        .field("temp", DataTypes.DOUBLE()))
                .createTemporaryTable("kafkaInput");
        
		// 使用source创建table
		Table table = tableEnv.from("fileInput");

		//使用TableAPI和SQL进行运算
        //TableAPI
        Table table = tableEnv.from("sensor");
        Table tableResult = table.groupBy("id").select("id,id.count,temp.avg");

        //SQL
        Table sqlResult = tableEnv.sqlQuery("select id,count(id) from sensor group by id");
```

## Sink

### (0) 输出到控制台

```java
// 追加输出
tableEnv.toAppendStream(apacheLog, Row.class).print("apacheLog");
// 撤回输出
tableEnv.toRetractStream(tableResult, Row.class).print("tableResult");
```

### (1) Sink-File

```java
//文件写出连接File
tableEnv.connect(new FileSystem()
                 // 设置路径
                 .path("sensorOut2"))
    // 添加文件格式化器,Csv表示使用,分隔
        .withFormat(new OldCsv())
    // 填入字段
        .withSchema(new Schema()
                .field("id", DataTypes.STRING())
                .field("ts", DataTypes.BIGINT())
                .field("temp", DataTypes.DOUBLE()))
    // 创建表并填入名称
        .createTemporaryTable("sensorOut2");

// 写出方法一:
tableEnv.insertInto("sensorOut2", sqlResult);
// 写出方法二:
sqlResult.insertInto("sensorOut2");
```

### (2) Sink-Kafka

```java
        tableEnv.connect(new Kafka()
                .version("0.11")
                .topic("test")
                .property(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "hadoop102:9092"))
                .withFormat(new Csv())
                .withSchema(new Schema()
                        .field("id", DataTypes.STRING())
                        .field("temp", DataTypes.DOUBLE()))
                .createTemporaryTable("kafkaSink");
// 写出
//        tableEnv.insertInto("kafkaSink", tableResult);
        sqlResult.insertInto("kafkaSink");
```

### (3) Sink-ES-Append

```java
// 
tableEnv.connect(
    new Elasticsearch()
        	// 版本
        	.version("6")
        	// 连接和协议
        	.host("hadoop102", 9200, "http")
       		// 索引
        	.index("flink_sql")
        	// type
        	.documentType("_doc"))
        //追加模式
        .inAppendMode()
    	// 模式必须选择json
        .withFormat(new Json())
        .withSchema(new Schema()
                .field("id", DataTypes.STRING())
                .field("temp", DataTypes.DOUBLE()))
        .createTemporaryTable("EsPath");
// 写入es
tableEnv.insertInto("EsPath", tableResult);
```

### (4)  Sink-ES-Upsert

```java
        tableEnv.connect(
                new Elasticsearch()
                        .version("6")
                        .host("hadoop102", 9200, "http")
                        .index("flink_sql04")
            			//禁用检查点刷新
                        .disableFlushOnCheckpoint()
            			// Flush刷写条数
                        .bulkFlushMaxActions(1)
            			// 刷写大小
            			.bulkFlushMaxSize("42 mb")
            			//刷写时间
                        .bulkFlushInterval(60000L)
                        .documentType("_doc"))
            	// 切换为更新模式
                .inUpsertMode()
                .withFormat(new Json())
                .withSchema(new Schema()
                        .field("id", DataTypes.STRING())
                        .field("ts", DataTypes.BIGINT())
                        .field("ct", DataTypes.BIGINT()))
                .createTemporaryTable("EsPath");

        tableEnv.insertInto("EsPath", sqlResult);
```

### (5) Sink-MySQL

```java
String sinkDDL = "create table jdbcOutputTable (" +
                " id varchar(20) not null, " +
                " ct bigint not null " +
                ") with (" +
                " 'connector.type' = 'jdbc', " +
                " 'connector.url' = 'jdbc:mysql://hadoop102:3306/test', " +
                " 'connector.table' = 'sensor_count1', " +
                " 'connector.driver' = 'com.mysql.jdbc.Driver', " +
                " 'connector.username' = 'root', " +
                " 'connector.password' = '000000', " +
                " 'connector.write.flush.max-rows' = '1'," + //刷写条数,默认5000
                " 'connector.write.flush.interval' = '2s')"; // 刷写时间,默认0s不启用

        tableEnv.sqlUpdate(sinkDDL);
        tableEnv.insertInto("jdbcOutputTable", tableResult);
```



## Proctime和EventTime

### (1) 在DataStream转换添加Proctime

```java
//SQL转换,添加一列 pt.proctime
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,pt.proctime");
```

### (2) 在Connect添加时添加Proctime

```java
tableEnv.connect(new FileSystem().path("sensor"))
        .withSchema(new Schema()
                .field("id", DataTypes.STRING())
                .field("ts", DataTypes.BIGINT())
                .field("temp", DataTypes.DOUBLE())
                 // 精度为3位
                .field("pt", DataTypes.TIMESTAMP(3)).proctime())
        .withFormat(new OldCsv())
        .createTemporaryTable("fileInput");
```

### (3) 在StringDDL中添加Proctime

```java
String sinkDDL = "create table dataTable (" +
        " id varchar(20) not null, " +
        " ts bigint, " +
        " temp double, " +
        " pt AS PROCTIME() " +
        ") with (" +
        " 'connector.type' = 'filesystem', " +
        " 'connector.path' = 'sensor', " +
        " 'format.type' = 'csv')";

bsTableEnv.sqlUpdate(sinkDDL);
```

### (4) 在DataStream转换时添加EventTime

```java
// 先在流中添加EventTime
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

SingleOutputStreamOperator<SensorReading> sensorDS = env.socketTextStream("hadoop102", 7777)
        .assignTimestampsAndWatermarks(new BoundedOutOfOrdernessTimestampExtractor<String>(Time.seconds(1)) {
            @Override
            public long extractTimestamp(String element) {
                String[] split = element.split(",");
                return Long.parseLong(split[1]) * 1000L;
            }
        })
        .map(line -> {
            String[] fields = line.split(",");
            return new SensorReading(fields[0], Long.parseLong(fields[1]), Double.parseDouble(fields[2]));
        });

// 将流转换为表 rt.rowtime 添加EventTime
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,rt.rowtime");
```

### (5) 在Connect 中添加EventTime

```java
tableEnv.connect(new FileSystem().path("sensor"))
        .withSchema(new Schema()
                .field("id", DataTypes.STRING())
                .field("ts", DataTypes.BIGINT())
                .field("temp", DataTypes.DOUBLE())
                .field("rt", DataTypes.BIGINT()).rowtime(new Rowtime()
                        .timestampsFromField("ts") //指定EventTime的列(不能使用算式)
                        .watermarksPeriodicBounded(1000)) //添加Watermark
        )
        .withFormat(new Csv())
        .createTemporaryTable("fileInput");
```

### (6) 在StringDDL中添加EventTime

```java
String sinkDDL = "create table dataTable (" +
        " id varchar(20) not null, " +
        " ts bigint, " +
        " temp double, " +
        " rt AS TO_TIMESTAMP( FROM_UNIXTIME(ts) ), " + // 指定EventTime的列
        " watermark for rt as rt - interval '1' second" + // 设置1s的watermark
        ") with (" +
        " 'connector.type' = 'filesystem', " +
        " 'connector.path' = 'sensor', " +
        " 'format.type' = 'csv')";
        
tableEnv.sqlUpdate(sinkDDL);
```

## Window

### (1) ProcessTime-Tumble

**TableAPI**

```java
// 设置执行时间
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,pt.proctime");

// 对pt进行5s滚动窗口开窗
Table result = table.window(Tumble.over("5.seconds").on("pt").as("sw"))
        .groupBy("id,sw")
        .select("id,id.count");
// 对pt进行5条信息,步长为2条信息开窗
Table result = table.window(Slide.over("5.rows").every("2.rows").on("pt").as("sw"))
        .groupBy("id,sw")
        .select("id,id.count");
```

**SQL**

```java
// 设置执行时间
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,pt.proctime");

// 创建视图
tableEnv.createTemporaryView("sensor", table);
// 使用sql
Table result = tableEnv.sqlQuery("select id,count(id) as ct,TUMBLE_end(pt,INTERVAL '5' second) from sensor " +
        "group by id,TUMBLE(pt,INTERVAL '5' second)");
```

### (2) EventTime-Tumble

```java
// 设置EventTime
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

SingleOutputStreamOperator<SensorReading> sensorDS = env.socketTextStream("hadoop102", 7777)
                .assignTimestampsAndWatermarks(new BoundedOutOfOrdernessTimestampExtractor<String>(Time.seconds(1)) {
                    @Override
                    public long extractTimestamp(String element) {
                        String[] split = element.split(",");
                        return Long.parseLong(split[1]) * 1000L;
                    }
                })
                .map(line -> {
                    String[] fields = line.split(",");
                    return new SensorReading(fields[0], Long.parseLong(fields[1]), Double.parseDouble(fields[2]));
                });
// 设置eventTime为单独一列
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,rt.rowtime");

//对EventTime进行滚动开窗
Table result = table.window(Tumble.over("5.seconds").on("rt").as("tw"))
            .groupBy("id,tw")
            .select("id,id.count,tw.end");
```

### (3) ProcessTime-Slide

```java
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,pt.proctime");
// 使用默认的处理时间,滑动开窗
Table result = table.window(Slide.over("5.seconds").every("2.seconds").on("pt").as("sw"))
        .groupBy("id,sw")
        .select("id,id.count");
// 使用默认的滑动条数,滑动开窗
Table result = table.window(Slide.over("5.rows").every("2.rows").on("pt").as("sw"))
        .groupBy("id,sw")
        .select("id,id.count");

//SQL
tableEnv.createTemporaryView("sensor", table);
Table result = tableEnv.sqlQuery("select id,count(id) as ct from sensor " +
      "group by id,hop(pt,INTERVAL '2' second,INTERVAL '6' second)");
```

### (4) EventTime-Slide

```java
// 注册使用事件时间
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);
sensorDS.assignTimestampsAndWatermarks(new BoundedOutOfOrdernessTimestampExtractor<String>(Time.seconds(1)) {
                    @Override
                    public long extractTimestamp(String element) {
                        String[] split = element.split(",");
                        return Long.parseLong(split[1]) * 1000L;
                    }
                });
```

```java
// 使用滑动开窗
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,rt.rowtime");
Table result = table.window(Slide.over("6.seconds").every("2.seconds").on("rt").as("tw"))
        .groupBy("id,tw")
        .select("id,id.count,tw.end");
```

### (5) ProcessTime-Session

```java
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,pt.proctime");

Table result = table.window(Session.withGap("5.seconds").on("pt").as("sw"))
        .groupBy("id,sw")
        .select("id,id.count");

//SQL
tableEnv.createTemporaryView("sensor", table);
Table result = tableEnv.sqlQuery("select id,count(id) as ct from sensor " +
         "group by id,session(pt,INTERVAL '5' second)");
```

### (6) EventTime-Session

```java
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

sensorDS.assignTimestampsAndWatermarks(new BoundedOutOfOrdernessTimestampExtractor<String>(Time.seconds(1)) {
                    @Override
                    public long extractTimestamp(String element) {
                        String[] split = element.split(",");
                        return Long.parseLong(split[1]) * 1000L;
                    }
                });

Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,rt.rowtime");

Table result = table.window(Session.withGap("5.seconds").on("rt").as("sw"))
                .groupBy("id,sw")
                .select("id,id.count");
```

### (7) ProcessTime-Over

```java
Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,pt.proctime");

Table result = table.window(Over.partitionBy("id").orderBy("pt").as("ow"))
    .select("id,id.count over ow");
Table result = table.window(Over.partitionBy("id").orderBy("pt").preceding("3.rows").as("ow"))
    .select("id,id.count over ow");

//SQL
tableEnv.createTemporaryView("sensor", table);
Table result = tableEnv.sqlQuery("select id,count(id) " +
                                 "over(partition by id order by pt) as ct " +
                                 "from sensor");
```

### (8) EventTime-Over

```java
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

sensorDS.assignTimestampsAndWatermarks(new BoundedOutOfOrdernessTimestampExtractor<String>(Time.seconds(1)) {
                    @Override
                    public long extractTimestamp(String element) {
                        String[] split = element.split(",");
                        return Long.parseLong(split[1]) * 1000L;
                    }
                });

Table table = tableEnv.fromDataStream(sensorDS, "id,ts,temp,rt.rowtime");

//        Table result = table.window(Over.partitionBy("id").orderBy("rt").as("ow"))
//                .select("id,id.count over ow");

        Table result = table.window(Over.partitionBy("id").orderBy("rt").preceding("3.rows").as("ow"))
                .select("id,id.count over ow");
```

## 自定义函数

### (1) Function-ScalarFunc

一进一出

```java
//注册函数
tableEnv.registerFunction("MyLength", new MyLength());

//TableAPI
Table tableResult = table.select("id,id.MyLength");

//6.SQL
tableEnv.createTemporaryView("sensor", table);
Table sqlResult = tableEnv.sqlQuery("select id,MyLength(id) from sensor");
```

```java
public static class MyLength extends ScalarFunction {

    public int eval(String value) {
        return value.length();
    }

}
```

### (2) Function-TableFunc

一进多出

```java
//注册函数
tableEnv.registerFunction("Split", new Split());

 //6.SQL
tableEnv.createTemporaryView("sensor", table);
Table sqlResult = tableEnv.sqlQuery("select id,word,length from sensor," +
                                    "LATERAL TABLE(Split(id)) as T(word, length)");
```

```java
public static class Split extends TableFunction<Tuple2<String, Integer>> {

    public void eval(String value) {
        String[] split = value.split("_");
        for (String s : split) {
            collector.collect(new Tuple2<>(s, s.length()));
        }
    }

}
```

### (3) Function-AggFunc

多进一出

```java
//注册函数
tableEnv.registerFunction("TempAvg", new TempAvg());

//TableAPI
Table tableResult = table
                .groupBy("id")
    			.select("id,temp.TempAvg");

//SQL
tableEnv.createTemporaryView("sensor", table);
Table sqlResult = tableEnv.sqlQuery("select id,TempAvg(temp) from sensor group by id");
```

```java
public static class TempAvg extends AggregateFunction<Double, Tuple2<Double, Integer>> {

    //初始化缓冲区
    @Override
    public Tuple2<Double, Integer> createAccumulator() {
        return new Tuple2<>(0.0D, 0);
    }

    //计算方法:所有值进入到缓冲区计算
    public void accumulate(Tuple2<Double, Integer> buffer, Double value) {
        buffer.f0 += value;
        buffer.f1 += 1;
    }

    //获取返回值结果:使用缓冲区保存的值
    @Override
    public Double getValue(Tuple2<Double, Integer> accumulator) {
        return accumulator.f0 / accumulator.f1;
    }

}
```

### (4) Function-TableAggFunc

多进多出

```java
tableEnv.registerFunction("Top2Temp", new Top2Temp());

//TableAPI
Table tableResult = table
                .groupBy("id")
    			.flatAggregate("Top2Temp(temp) as (temp,rank)")
    			.select("id,temp,rank");
```

```java
public static class Top2Temp extends TableAggregateFunction<Tuple2<Double, Integer>, Tuple2<Double, Double>> {

    @Override
    public Tuple2<Double, Double> createAccumulator() {
        return new Tuple2<>(Double.MIN_VALUE, Double.MIN_VALUE);
    }

    public void accumulate(Tuple2<Double, Double> buffer, Double value) {

        //1.将输入数据跟第一个比较
        if (value > buffer.f0) {
            buffer.f1 = buffer.f0;
            buffer.f0 = value;
        } else if (value > buffer.f1) {
            //2.将输入数据跟第二个比较
            buffer.f1 = value;
        }
    }

    public void emitValue(Tuple2<Double, Double> buffer, Collector<Tuple2<Double, Integer>> collector) {
        collector.collect(new Tuple2<>(buffer.f0, 1));
        if (buffer.f1 != Double.MIN_VALUE) {
            collector.collect(new Tuple2<>(buffer.f1, 2));
        }
    }
}
```

