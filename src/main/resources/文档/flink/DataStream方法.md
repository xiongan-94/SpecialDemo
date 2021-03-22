## WordCount案例

使用流程：

### （0）添加依赖：

```xml
<properties>
    <flink.version>1.10.1</flink.version>
    <scala.binary.version>2.12</scala.binary.version>
    <kafka.version>2.2.0</kafka.version>
</properties>

<dependencies>
    <dependency>
        <groupId>org.apache.flink</groupId>
        <artifactId>flink-java</artifactId>
        <version>${flink.version}</version>
    </dependency>
    <dependency>
        <groupId>org.apache.flink</groupId>
        <artifactId>flink-streaming-java_${scala.binary.version}</artifactId>
        <version>${flink.version}</version>
    </dependency>
    <dependency>
        <groupId>org.apache.kafka</groupId>
        <artifactId>kafka_${scala.binary.version}</artifactId>
        <version>${kafka.version}</version>
    </dependency>
    <dependency>
        <groupId>org.apache.flink</groupId>
        <artifactId>flink-connector-kafka_${scala.binary.version}</artifactId>
        <version>${flink.version}</version>
    </dependency>
</dependencies>
```

### （1）获取环境：

批处理

```java
ExecutionEnvironment.getExecutionEnvironment();
```

流处理：

```java
StreamExecutionEnvironment.getExecutionEnvironment();
```

### （2）添加source：

从文件

```java
env.readTextFile("input");
```

从端口

```java
env.socketTextStream("hadoop102", 7777);
```

### （3）运算：

```java
lineDS.flatMap(new Flink01_WordCount_Batch.MyFlatMapFunc());
```

### （4）打印并执行：

```java
result.print();
env.execute();
```



##  设置并行度

```java
//代码全局设置并行度
//env.setParallelism(2);
//设置单个算子并行度
 lineDS.flatMap(new Flink01_WordCount_Batch.MyFlatMapFunc()).setParallelism(2);
```



## Source

### (1) 从集合中创建数据流

```java
//2.读取集合数据创建流
DataStreamSource<SensorReading> sensorDS = env.fromCollection(Arrays.asList(
        new SensorReading("sensor_1", 1547718199L, 35.8),
        new SensorReading("sensor_6", 1547718201L, 15.4),
        new SensorReading("sensor_7", 1547718202L, 6.7),
        new SensorReading("sensor_10", 1547718205L, 38.1)
));
```



### (2) 从文件读取数据流

```java
env.readTextFile("sensor");
```



### (3) 从kafka获取数据流

```java
        // 设置连接服务器
		properties.setProperty("bootstrap.servers", "hadoop102:9092");
		// 设置消费者组
        properties.setProperty("group.id", "consumer-group");
		// 设置key编码
        properties.setProperty("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
		// 设置value编码
        properties.setProperty("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
		// 设置消费模式,lastst 表示最尾 earliest 从头开始消费
        properties.setProperty("auto.offset.reset", "latest");

// 创建kafka消费者对象,添加一个解码器,添加配置的properties
env.addSource(new FlinkKafkaConsumer011<String>("test",
        new SimpleStringSchema(),
        properties));
```



### (4) 从自定义的source中获取数据流

```java
env.addSource(new CustomerSource());
```

```java
public static class CustomerSource implements SourceFunction<SensorReading> {
    @Override
        public void run(SourceContext ctx) throws Exception {
            ctx.collect(/传入的数据/)
        }
    //调用的关闭方法
    @Override
        public void cancel() {
            running = false;
        }
}
```



## Transform

### (1) map方法

一行进一行出

```java
// DataStreamSource -> SingleOutputStreamOperator
fileDS.map(new MapFunction<String, SensorReading>() {
    @Override
    public SensorReading map(String value) throws Exception {
        String[] fields = value.split(",");
        // return的是输出数据
        return new SensorReading(fields[0],
                Long.parseLong(fields[1]),
                Double.parseDouble(fields[2]));
    }
});
```



### (2) flatMap

压平操作

```java
// DataStreamSource -> SingleOutputStreamOperator
fileDS.flatMap(new FlatMapFunction<String, String>() {
    @Override
    public void flatMap(String value, Collector<String> out) throws Exception {
        String[] split = value.split(",");
        for (String s : split) {
            // 输出数据
            out.collect(s);
        }
    }
});
```



### (3) filter

过滤

```java
// DataStreamSource -> SingleOutputStreamOperator
fileDS.filter(new FilterFunction<String>() {
    @Override
    public boolean filter(String value) throws Exception {
        double temp = Double.parseDouble(value.split(",")[2]);
        return temp > 30.0D;
    }
});
```



### (4) keyby

分组 (适用于元组和类)

```java
// DataStream -> KeyedStream
sensorDS.keyBy(0);
sensorDS.keyBy("id");
```



### (5) 滚动聚合算子



```java
// 替换单个数值sum()
// min()
// max()
// 替换整条minBy()
// maxBy()
// DataStream → KeyedStream
SingleOutputStreamOperator<SensorReading> maxResult = keyedStream.max("temp");
```



### (6)Reduce

聚合算子



```java
//聚合操作,用于KeyedStream → DataStream

keyedStream.reduce(new ReduceFunction<SensorReading>() {
        /**
         * 返回类型和结果类型相同
         * @param value1 传入的前一个数据
         * @param value2 传入的后一个数据
         * @return 需要聚合的结果
         * @throws Exception
         */
    @Override
    public SensorReading reduce(SensorReading value1, SensorReading value2) throws Exception {
        return new SensorReading(value1.getId(),
                value2.getTs(),
                Math.max(value1.getTemp(), value2.getTemp()));
    }
});
```



### (7)Split 和 Select

![1606136901985](C:\Users\yhm\AppData\Roaming\Typora\typora-user-images\1606136901985.png)



**DataStream** **→** **SplitStream**：根据某些特征把一个DataStream拆分成两个或者多个DataStream。





```java
//DataStream → SplitStream

SplitStream<SensorReading> split = sensorDS.split(new OutputSelector<SensorReading>() {
            /**
             * 根据传入值特征进行选择,返回单个元素的列表,表示分流
             * @param value
             * @return
             */
            @Override
            public Iterable<String> select(SensorReading value) {
                return value.getTemp() > 30 ?
                        Collections.singletonList("high") : Collections.singletonList("low");
            }
        });

```

![1606136919437](C:\Users\yhm\AppData\Roaming\Typora\typora-user-images\1606136919437.png)

**SplitStream**→**DataStream**：从一个SplitStream中获取一个或者多个DataStream。

```java
// 选择流
DataStream<SensorReading> high = split.select("high");
DataStream<SensorReading> low = split.select("low");
DataStream<SensorReading> all = split.select("high","low");
```



### (8) Connect和 CoMap

![1606137153013](C:\Users\yhm\AppData\Roaming\Typora\typora-user-images\1606137153013.png)



**DataStream,DataStream→ ConnectedStreams**：连接两个保持他们类型的数据流，两个数据流被Connect之后，只是被放在了一个同一个流中，内部依然保持各自的数据和形式不发生任何变化，两个流相互独立。



```java
// 连接两个流
ConnectedStreams<Tuple2<String, Double>, SensorReading> connect = high.connect(low);
```



![1606137228926](C:\Users\yhm\AppData\Roaming\Typora\typora-user-images\1606137228926.png)



```java
// 可以使用CoMap,CoFlatMap对应map和flatMap方法
SingleOutputStreamOperator<Object> map = connect.map(new CoMapFunction<Tuple2<String, Double>, SensorReading, Object>() {
    /**
     * 前一个流的映射
     * @param value
     * @return
     * @throws Exception
     */
    @Override
    public Object map1(Tuple2<String, Double> value) throws Exception {
        return new Tuple3<String, Double, String>(value.f0, value.f1, "warn");
    }
    /**
     * 后一个流的映射
     * @param value
     * @return
     * @throws Exception
     */
    @Override
    public Object map2(SensorReading value) throws Exception {
        return new Tuple2<String, String>(value.getId(), "healthy");
    }
});
```



### (9) Union

![1606137323447](C:\Users\yhm\AppData\Roaming\Typora\typora-user-images\1606137323447.png)

**DataStream** **→** **DataStream**：对两个或者两个以上的DataStream进行union操作，产生一个包含所有DataStream元素的新DataStream。

```java
// 和connect不同,union完全合并为一个流
DataStream<SensorReading> all = high.union(low);
```

### (10) 复函数  

例如 RichMap

```java
public static class MyRichMapFunc extends RichMapFunction<String, SensorReading> {
        /**
         * 用于定义状态
         * @param parameters
         * @throws Exception
         */
        @Override
        public void open(Configuration parameters) throws Exception {
            //创建连接
            super.open(parameters);
            System.out.println("open方法被调用");
        }
        /**
         * 映射计算
         * @param value
         * @return
         * @throws Exception
         */
        @Override
        public SensorReading map(String value) throws Exception {
            //使用连接
            String[] fields = value.split(",");
            return new SensorReading(fields[0],
                    Long.parseLong(fields[1]),
                    Double.parseDouble(fields[2]));
        }
        /**
         * 结束调用,关闭资源
         * @throws Exception
         */
        @Override
        public void close() throws Exception {
            //关闭连接
            super.close();
            System.out.println("close方法被调用");
        }
    }
```

## Sink

### (1) Kafka-Sink

```java
// 使用固定类,添加url,topic,定义的序列化架构(SimpleStringSchema 一个UTF-8序列化) 
inputDS.addSink(new FlinkKafkaProducer011<String>("hadoop102:9092", "topic", new SimpleStringSchema()));
```



### (2) Redis-Sink



```java
// 添加连接的配置
FlinkJedisPoolConfig config = new FlinkJedisPoolConfig.Builder()
        .setHost("hadoop102")
        .setPort(6379)
        .build();
//添加sink,使用系统的类,同时传入配置和实现接口RedisMapper
inputDS.addSink(new RedisSink<>(config, new MyRedisMapper()));
```

```java
//需要自定义实现 RedisMapper
public static class MyRedisMapper implements RedisMapper<String> {

         /**
         * 使用redis的添加指令和key的前缀
         * @return
         */
        @Override
        public RedisCommandDescription getCommandDescription() {
            return new RedisCommandDescription(RedisCommand.HSET, "sensor");
        }

        /**
         * 数据中key的部分,配合上面的key前缀
         * @param data
         * @return
         */
        @Override
        public String getKeyFromData(String data) {
            String[] fields = data.split(",");
            return fields[0];
        }

        /**
         * 传入的value部分
         * @param data
         * @return
         */
        @Override
        public String getValueFromData(String data) {
            String[] fields = data.split(",");
            return fields[2];
        }
}
```

### (3) ES-Sink

```java
//创建集合用于存放连接条件
ArrayList<HttpHost> httpHosts = new ArrayList<>();
httpHosts.add(new HttpHost("hadoop102", 9200));
```

```java
// 创建EsSink 建造者模式,添加连接列表和实现接口ElasticsearchSinkFunction
ElasticsearchSink<String> elasticsearchSink =
        new ElasticsearchSink.Builder<>(httpHosts, new MyEsSinkFunc())
                .build();
```

```java
public static class MyEsSinkFunc implements ElasticsearchSinkFunction<String> {

        /**
         * 使用map保存数据实体,构建索引需求来写入es
         * @param element
         * @param ctx
         * @param indexer
         */
        @Override
        public void process(String element, RuntimeContext ctx, RequestIndexer indexer) {

            //对元素分割处理
            String[] fields = element.split(",");

            //创建Map用于存放待存储到ES的数据
            HashMap<String, String> source = new HashMap<>();
            source.put("id", fields[0]);
            source.put("ts", fields[1]);
            source.put("temp", fields[2]);

            //创建IndexRequest
            IndexRequest indexRequest = Requests.indexRequest()
                    .index("sensor")
                    .type("_doc")
//                    .id(fields[0])
                    .source(source);

            //将数据写入
            indexer.add(indexRequest);

        }
    }
```

### (4)JDBC-Sink

```java
//直接添加实现接口RichSinkFunction
inputDS.addSink(new JdbcSink());
```

```java
public static class JdbcSink extends RichSinkFunction<String> {

    //声明MySQL相关的属性信息
    Connection connection = null;
    PreparedStatement preparedStatement = null;

    /**
     *  连接Mysql和编译sql
     * @param parameters
     * @throws Exception
     */
    @Override
    public void open(Configuration parameters) throws Exception {
        connection = DriverManager.getConnection("jdbc:mysql://hadoop102:3306/test", "root", "000000");
        preparedStatement = connection.prepareStatement("INSERT INTO sensor(id,temp) VALUES(?,?) ON DUPLICATE KEY UPDATE temp=?");
    }

    /**
     * 数据添加进sql中
     * @param value
     * @param context
     * @throws Exception
     */
    @Override
    public void invoke(String value, Context context) throws Exception {
        //分割数据
        String[] fields = value.split(",");
        //给预编译SQL赋值
        preparedStatement.setString(1, fields[0]);
        preparedStatement.setDouble(2, Double.parseDouble(fields[2]));
        preparedStatement.setDouble(3, Double.parseDouble(fields[2]));
        //执行
        preparedStatement.execute();
    }

    /**
     * 关闭资源
     * @throws Exception
     */
    @Override
    public void close() throws Exception {
        preparedStatement.close();
        connection.close();
    }
}
```



## Window

KeyedStream使用开窗函数Window到WindowedStream;

DataStream使用开窗函数WindowAll到AllWindowedStream

### (1) 滚动时间开窗

```java
// timeWindow只填写一个参数为滚动开创
// KeyedStream -> WindowedStream
WindowedStream<Tuple2<String, Integer>, Tuple, TimeWindow> windowDStream = keyedStream.timeWindow(Time.seconds(5));
```

### (2) 滑动时间开窗

```java
// 填写两个参数,第一个为窗口大小,第二个为滑动时长
// KeyedStream -> WindowedStream
WindowedStream<Tuple2<String, Integer>, Tuple, TimeWindow> windowDStream = keyedStream.timeWindow(Time.seconds(6), Time.seconds(2));
```

### (3)使用Offset开窗

```java
// 使用抽象类WindowAssigner的子类填入window函数中
// KeyedStream -> WindowedStream
WindowedStream<Tuple2<String, Integer>, Tuple, TimeWindow> window = keyedStream.window(TumblingProcessingTimeWindows.of(Time.seconds(5), Time.seconds(1)));
```

### (4) 会话时间开窗

```java
// KeyedStream -> WindowedStream
// 使用WindowAssigner的子类 ProcessingTimeSessionWindows的withGap方法进行会话开窗
// 会话间隔为5秒
WindowedStream<Tuple2<String, Integer>, Tuple, TimeWindow> window = keyedStream.window(ProcessingTimeSessionWindows.withGap(Time.seconds(5)));
```

### (5) 滚动计数开窗

```java
// 只填一个参数为滚动
// KeyedStream -> WindowedStream
WindowedStream<Tuple2<String, Integer>, Tuple, GlobalWindow> window = keyedStream.countWindow(5);
```

### (6) 滑动计数开窗

```java
// 填两个参数,一个为窗口大小,一个是滑动步长
// KeyedStream -> WindowedStream
WindowedStream<Tuple2<String, Integer>, Tuple, GlobalWindow> window = keyedStream.countWindow(5, 2);
```

### (7) Apply窗口中的计算

```java
// 开窗后的流使用apply调用WindowFunction接口实现的类转变为DataStream
// WindowedStream -> DataStream
SingleOutputStreamOperator<Integer> sum = windowDStream.apply(new MyWindowFunc()
```

```java
public static class MyWindowFunc implements WindowFunction<Tuple2<String, Integer>, Integer, Tuple, TimeWindow> {

    /**
     * 
     * @param tuple 聚合key值
     * @param window 记录窗口的开闭时间
     * @param input 传入数据
     * @param out 传出数据收集器
     * @throws Exception
     */
    @Override
    public void apply(Tuple tuple, TimeWindow window, Iterable<Tuple2<String, Integer>> input, Collector<Integer> out) throws Exception {

        Integer count = 0;
        Iterator<Tuple2<String, Integer>> iterator = input.iterator();
        while (iterator.hasNext()) {
            Tuple2<String, Integer> next = iterator.next();
            count += 1;
        }

        out.collect(count);
    }
}
```

### (8) AggregateFunc + Apply

```java
// 先使用AggregateFunc进行聚合,之后使用apply整合输出
SingleOutputStreamOperator<UrlViewCount> urlViewCountDS = apacheLogStringTimeWindowStream
        .aggregate(new HotUrlAggregateFunc(), new HotUrlWindowFunc());

	/**
     * AggregateFunction 每条信息进行count
     */
    private static class HotUrlAggregateFunc implements AggregateFunction<ApacheLog, Long, Long> {
        @Override
        public Long createAccumulator() {
            return 0L;
        }

        @Override
        public Long add(ApacheLog value, Long accumulator) {
            return ++accumulator;
        }

        @Override
        public Long getResult(Long accumulator) {
            return accumulator;
        }

        @Override
        public Long merge(Long a, Long b) {
            return a + b;
        }
    }

    /**
     * WindowFunction 整个window的数据输出UrlViewCount
     */
    private static class HotUrlWindowFunc implements WindowFunction<Long, UrlViewCount,String,TimeWindow> {
        @Override
        public void apply(String s, TimeWindow window, Iterable<Long> input, Collector<UrlViewCount> out) throws Exception {
            Iterator<Long> iterator = input.iterator();
            Long itemCount = iterator.next();
            long endTime = window.getEnd();

            out.collect(new UrlViewCount(s, endTime, itemCount));
        }
    }
```

## 时间语义

**Event Time**：是事件创建的时间,指定数据中的值

**Ingestion Time**：是数据进入Flink的时间

**Processing Time**：是每一个执行基于时间操作的算子的本地系统时间,默认的时间属性就是Processing Time。

### (1) 指定Event Time

```java
// 指定使用Event Time,默认使用Processing Time
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);
// 对DataStream使用assignTimestampsAndWatermarks函数,实现一个抽象类返回 Event Time
SingleOutputStreamOperator<String> input = dataStreamSource.assignTimestampsAndWatermarks(new AscendingTimestampExtractor<String>() {
            /**
             *  Event Time 一个时间戳
             * @param element 传入的数据
             * @return
             */
            @Override
            public long extractAscendingTimestamp(String element) {
                String[] fields = element.split(",");
                return Long.parseLong(fields[1]) * 1000L;
            }
        });
```

### (2) 开窗允许延迟时间

```java
// 指定使用Event Time,默认使用Processing Time
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);
// 对DataStream使用assignTimestampsAndWatermarks函数,实现一个抽象类返回 Event Time
SingleOutputStreamOperator<String> input = dataStreamSource.assignTimestampsAndWatermarks(new AscendingTimestampExtractor<String>() {
            /**
             *  Event Time 一个时间戳
             * @param element 传入的数据
             * @return
             */
            @Override
            public long extractAscendingTimestamp(String element) {
                String[] fields = element.split(",");
                return Long.parseLong(fields[1]) * 1000L;
            }
        });

// 开窗5秒,允许迟到2秒,在5s数据到时,计算0-5s数据,5-7s内,有0-5s数据到都会再次触发计算;
// 在7秒数据到时,关闭0-5s的窗口
// 关闭窗口之后,再到的数据传入侧输出流
WindowedStream<Tuple2<String, Integer>, Tuple, TimeWindow> windowedStream = keyedStream
                .timeWindow(Time.seconds(5))
                .allowedLateness(Time.seconds(2))
    			// 加{}确认泛型
                .sideOutputLateData(new OutputTag<Tuple2<String, Integer>>("sideOutPut"){});
```

### (3)EventTime和Watermark

```java
// 指定使用Event Time,默认使用Processing Time
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

// 将AscendingTimestampExtractor 改为BoundedOutOfOrdernessTimestampExtractor 
// 添加的参数为Watermark 
// Watermark 和允许延迟时间能够叠加
// 之后开窗的计算时间和关闭时间都会按照 Watermark 计算,全部延迟2s
SingleOutputStreamOperator<String> input = env.socketTextStream("hadoop102", 7777).assignTimestampsAndWatermarks(new BoundedOutOfOrdernessTimestampExtractor<String>(Time.seconds(2)) {
            @Override
            public long extractTimestamp(String element) {
                String[] fields = element.split(",");
                return Long.parseLong(fields[1]) * 1000L;
            }
        });
```

**当并发度不为1时,接收上游传下的 Watermark 以最小值向下传递,全部达到标准时,才会进行计算和关闭**



### (4) 处理网络延迟造成的数据延迟问题

设置eventTime,并添加watermark 1s

```java
// 使用EventTime
env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);
// 设置EventTime并添加1s的waterma
SingleOutputStreamOperator<ApacheLog> apacheLogDS = logDS.assignTimestampsAndWatermarks(new BoundedOutOfOrdernessTimestampExtractor<ApacheLog>(Time.seconds(1)) {
                    @Override
                    public long extractTimestamp(ApacheLog element) {
                        return element.getEventTime();
                    }
                });

// 分组开窗并设置60s的允许延迟数据
apacheLogDS
          .keyBy(apacheLog -> apacheLog.getUrl())
          .timeWindow(Time.minutes(10), Time.seconds(5))
          .allowedLateness(Time.seconds(60));


	/**
     * 在窗口完全关闭时再清空状态,避免数据丢失
     * 启动定时器,输出topN
     */
    private static class HotUrlProcessFunc extends KeyedProcessFunction<Long,UrlViewCount,String> {

        private Integer topSize;
        public HotUrlProcessFunc() {
        }
        public HotUrlProcessFunc(Integer topSize) {
            this.topSize = topSize;
        }
        // 定义状态
        private MapState<String,UrlViewCount> urlCountMap;

        @Override
        public void open(Configuration parameters) throws Exception {
            urlCountMap = getRuntimeContext().getMapState(new MapStateDescriptor<String, UrlViewCount>("urlCountMap", String.class, UrlViewCount.class));
        }

        @Override
        public void processElement(UrlViewCount value, Context ctx, Collector<String> out) throws Exception {
            urlCountMap.put(value.getUrl(),value);
            // 触发计算
            ctx.timerService().registerEventTimeTimer(value.getWindowEnd() + 1L);
            // 触发清空状态
            ctx.timerService().registerEventTimeTimer(value.getWindowEnd() + 60000L);
        }

        @Override
        public void onTimer(long timestamp, OnTimerContext ctx, Collector<String> out) throws Exception {
            // 清空状态(避免数据丢失)
            if (ctx.getCurrentKey() + 60000L == timestamp){
                urlCountMap.clear();
                return;
            }
            ArrayList<Map.Entry<String, UrlViewCount>> entries = Lists.newArrayList(urlCountMap.entries().iterator());
            // 排序
            entries.sort(new Comparator<Map.Entry<String, UrlViewCount>>() {
                @Override
                public int compare(Map.Entry<String, UrlViewCount> o1, Map.Entry<String, UrlViewCount> o2) {
                    return o2.getValue().getCount().compareTo(o1.getValue().getCount());
                }
            });
            StringBuilder result = new StringBuilder();

            Date date = new Date(entries.get(0).getValue().getWindowEnd());
            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

            result.append("================\n").append(sdf.format(date)).append("\n");

            for (int i = 0 ; i < Math.min(topSize,entries.size());i++){
                result.append("No ").append(i+1).append(":")
                        .append("  UTL:")
                        .append(entries.get(i).getValue().getUrl())
                        .append("  浏览量:")
                        .append(entries.get(i).getValue().getCount())
                        .append("\n");
            }
            result.append("===============\n\n");

            Thread.sleep(1000);
            out.collect(result.toString());
        }
    }
```

### (5) 数据丢失问题

在使用侧输出流接受超出允许迟到时间的数据时,数据会在多线程的各个窗口全部关闭之后才会被放入到侧输出中,如果数据传入到个别关闭的窗口中,就会有数据丢失.

## ProcessAPI

### (1) ProcessAPI介绍

```java
// 对keyedStream调用process函数,传入KeyedProcessFunction抽象类的实现
SingleOutputStreamOperator<String> process = keyedStream.process(new MyKeyedProcessFunc());
```

```java
// process函数对比普通函数有生命周期方法和定时器方法
// process函数对比rich函数多出定时器方法
public static class MyKeyedProcessFunc extends KeyedProcessFunction<Tuple, SensorReading, String> {

    //生命周期方法
    @Override
    public void open(Configuration parameters) throws Exception {
        super.open(parameters);
    }
    //生命周期方法
    @Override
    public void close() throws Exception {
        super.close();
    }
    
    /**
     *
     * @param value 传入数据
     * @param ctx 连接,用于输出侧输出流
     * @param out 输出收集器
     * @throws Exception
     */
    @Override
    public void processElement(SensorReading value, Context ctx, Collector<String> out) throws Exception {

        //状态编程相关
        RuntimeContext runtimeContext = getRuntimeContext();
        //ValueState<Object> state = runtimeContext.getState();

        //获取当前的Key以及时间戳
        Tuple currentKey = ctx.getCurrentKey();
        Long timestamp = ctx.timestamp();

        //定时服务参数
        //获取定时器
        //TimerService timerService = ctx.timerService();
        //获取当前处理时间,返回时间戳
        //timerService.currentProcessingTime();
        //设置一个定时器,传入参数为时间戳
        //timerService.registerProcessingTimeTimer(111L);
        //删除一个定时器,以定时器时间戳为标准
        //timerService.deleteProcessingTimeTimer(111L);
        //定时服务相关
        TimerService timerService = ctx.timerService();
        long ts = timerService.currentProcessingTime();
        timerService.registerProcessingTimeTimer(ts + 5000L);
        out.collect(value.getId());

        
        //根据温度高低将数据发送至不同的流
        if (temp > 30.0D) {
            //高温数据,发送数据至主流
            out.collect(value);
        } else {
            //低温数据,发送数据至低温流
            ctx.output(new OutputTag<String>("low"){}, value.getId());
        }
        //侧输出流
        //ctx.output();
    }

    //定时服务相关
    @Override
    public void onTimer(long timestamp, OnTimerContext ctx, Collector<String> out) throws Exception {
        //使用out输出内容
        out.collect("定时器工作了！");
        super.onTimer(timestamp, ctx, out);
    }
}
```

### (2) 状态使用

状态使用可以用ProcessAPI实现,也可以使用Rich函数实现

**需求:判断温度是否跳变,如果跳变超过10度,则报警**

```java
//调用自定义的Rich函数
SingleOutputStreamOperator<Tuple3<String, Double, Double>> result = keyedStream.flatMap(new MyTempIncFunc());



public static class MyTempIncFunc extends RichFlatMapFunction<SensorReading, Tuple3<String, Double, Double>> {

        //声明上一次温度值的状态
        private ValueState<Double> lastTempState = null;

        /**
         * 状态初始化一般在open中(DataStream需要等env.execute才会运行,提前初始化会报错)
         * @param parameters
         * @throws Exception
         */
        @Override
        public void open(Configuration parameters) throws Exception {
            //给状态做初始化 固定方法:获取连接之后注册一个变量作为状态属性
            lastTempState = getRuntimeContext().getState(new ValueStateDescriptor<Double>("last-temp", Double.class));
        }

        /**
         * 处理数据的方法,中间可以使用状态的值
         * @param value
         * @param out
         * @throws Exception
         */
        @Override
        public void flatMap(SensorReading value, Collector<Tuple3<String, Double, Double>> out) throws Exception {

            //a.获取上一次温度值以及当前的温度值
            Double lastTemp = lastTempState.value();
            Double curTemp = value.getTemp();

            //b.判断跳变是否超过10度
            if (lastTemp != null && Math.abs(lastTemp - curTemp) > 10.0) {
                out.collect(new Tuple3<>(value.getId(), lastTemp, curTemp));
            }

            //c.更新状态
            lastTempState.update(curTemp);

        }
    }
```

### (3) 定时器使用

**需求:判断温度10秒没有下降,则报警**



```java
SingleOutputStreamOperator<String> result = keyedStream.process(new MyKeyedProcessFunc());


public static class MyKeyedProcessFunc extends KeyedProcessFunction<Tuple, SensorReading, String> {

        //定义状态
        private ValueState<Double> lastTempState = null;
        // 记录定时器时间,用于删除定时器
        private ValueState<Long> tsState = null;
        //初始化状态
        @Override
        public void open(Configuration parameters) throws Exception {
            lastTempState = getRuntimeContext().getState(new ValueStateDescriptor<Double>("last-temp", Double.class));
            tsState = getRuntimeContext().getState(new ValueStateDescriptor<Long>("ts", Long.class));
        }

        @Override
        public void processElement(SensorReading value, Context ctx, Collector<String> out) throws Exception {

            //提取上一次的温度值
            Double lastTemp = lastTempState.value();
            Long lastTs = tsState.value();
            long ts = ctx.timerService().currentProcessingTime() + 5000L;

            //第一条数据,需要注册定时器
            if (lastTs == null) {
                ctx.timerService().registerProcessingTimeTimer(ts);
                tsState.update(ts);
            } else if (value.getTemp() < lastTemp) {
                //非第一条数据,则需要判断温度是否下降
                //删除定时器
                ctx.timerService().deleteProcessingTimeTimer(tsState.value());
                //重新注册新的定时器
                ctx.timerService().registerProcessingTimeTimer(ts);
                tsState.update(ts);
            }

            //更新状态
            lastTempState.update(value.getTemp());

        }

        @Override
        public void onTimer(long timestamp, OnTimerContext ctx, Collector<String> out) throws Exception {
            out.collect(ctx.getCurrentKey() + "连续10秒温度没有下降");
            tsState.clear();
        }
    }
```

### (4) 配置状态后端保存

```java
//配置状态后端
// hdfs文件保存
env.setStateBackend(new FsStateBackend("hdfs://"));
// 内存保存
env.setStateBackend(new MemoryStateBackend());
// 本地文件保存
env.setStateBackend(new RocksDBStateBackend(""));

//CK相关设置
// 保存周期
env.enableCheckpointing(10000L);
// 修改保存周期
env.getCheckpointConfig().setCheckpointInterval(10000L);
// 保存超时时间
env.getCheckpointConfig().setCheckpointTimeout(1000000L);
// 最大并发保存
env.getCheckpointConfig().setMaxConcurrentCheckpoints(2);
// 保存语义模式EXACTLY_ONCE
env.getCheckpointConfig().setCheckpointingMode(CheckpointingMode.EXACTLY_ONCE);
// 保存时间最小头尾时间
env.getCheckpointConfig().setMinPauseBetweenCheckpoints(1000L);
// 如果有更近的ck,是否使用ck恢复数据,而不使用savePoint
env.getCheckpointConfig().setPreferCheckpointForRecovery(true);
```

