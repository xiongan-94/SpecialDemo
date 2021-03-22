## Flink架构

![1606392103855](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606392103855.png)

Apache Flink是为分布式、高性能、随时可用以及准确的流处理应用程序打造的开源流处理框架.



## Flink的重要特点

### (1) 事件驱动型(Event-driven)

事件驱动型应用是一类具有状态的应用，它从一个或多个事件流提取数据，并根据到来的事件触发计算、状态更新或其他外部动作。比较典型的就是以**kafka**为代表的消息队列几乎都是事件驱动型应用。

与之不同的就是SparkStreaming微批次，如图：

![img](D:\大数据查询资料\flink\photo\clip_image002.jpg)

事件驱动型：

![1606392366207](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606392366207.png)

### (2) 流与批的世界观

**批处理**的特点是有界、持久、大量，非常适合需要访问全套记录才能完成的计算工作，一般用于离线统计。

**流处理**的特点是无界、实时,  无需针对整个数据集执行操作，而是对通过系统传输的每个数据项执行操作，一般用于实时统计。

在spark的世界观中，一切都是由批次组成的，离线数据是一个大批次，而实时数据是由一个一个无限的小批次组成的。

而在flink的世界观中，一切都是由流组成的，离线数据是有界限的流，实时数据是一个没有界限的流，这就是所谓的有界流和无界流。

**无界数据流**：无界数据流有一个开始但是没有结束，它们不会在生成时终止并提供数据，必须连续处理无界流，也就是说必须在获取后立即处理event。对于无界数据流我们无法等待所有数据都到达，因为输入是无界的，并且在任何时间点都不会完成。处理无界数据通常要求以特定顺序（例如事件发生的顺序）获取event，以便能够推断结果完整性。

**有界数据流**：有界数据流有明确定义的开始和结束，可以在执行任何计算之前通过获取所有数据来处理有界流，处理有界流不需要有序获取，因为可以始终对有界数据集进行排序，有界流的处理也称为批处理。

## flink安装模式

### (1) Standalone模式

安装并分发集群机器:

```bash
# 启动集群
bin/start-cluster.sh 
# 直接运行
bin/flink run -c com.user1.wc.Flink03_WordCount_Unbounded –p 2 FlinkTutorial-1.0-SNAPSHOT-jar-with-dependencies.jar --host hadoop102 --port 7777 
```

### (2) yarn-**Session-cluster**

![1606392722483](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606392722483.png)

Session-Cluster模式需要先启动集群，然后再提交作业，接着会向yarn申请一块空间后，资源永远保持不变。如果资源满了，下一个作业就无法提交，只能等到yarn中的其中一个作业执行完成后，释放了资源，下个作业才会正常提交。所有作业共享Dispatcher和ResourceManager；共享资源；适合规模小执行时间短的作业。

在yarn中初始化一个flink集群，开辟指定的资源，以后提交任务都向这里提交。这个flink集群会常驻在yarn集群中，除非手工停止。

```bash
# 启动yarn-session
-s(--slots)：	每个TaskManager的slot数量，默认一个slot一个core，默认每个taskmanager的slot的个数为1，有时可以多一些taskmanager，做冗余。
-jm：JobManager的内存（单位MB)。
-tm：每个taskmanager的内存（单位MB)。
-nm：yarn 的appName(现在yarn的ui上的名字)。 

bin/yarn-session.sh  -s 2 -jm 1024 -tm 1024 -nm test 

# 执行任务
./flink run -c com.user1.wc.Flink03_WordCount_Unbounded FlinkTutorial-1.0-SNAPSHOT-jar-with-dependencies.jar --host hadoop102 --port 7777


# 取消yarn-session
yarn application --kill application_1577588252906_0001
```



### (3) yarn-Per Job Cluster

![1606392883702](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606392883702.png)

一个Job会对应一个集群，每提交一个作业会根据自身的情况，都会单独向yarn申请资源，直到作业执行完成，一个作业的失败与否并不会影响下一个作业的正常提交和运行。独享Dispatcher和ResourceManager，按需接受资源申请；适合规模大长时间运行的作业。

每次提交都会创建一个新的flink集群，任务之间互相独立，互不影响，方便管理。任务执行完成之后创建的集群也会消失。

```bash
#不启动yarn-session，直接执行job
./flink run –m yarn-cluster -c com.user1.wc.Flink03_WordCount_Unbounded FlinkTutorial-1.0-SNAPSHOT-jar-with-dependencies.jar --host hadoop102 --port 7777

```

## flink运行时组件

作业管理器（JobManager）: 控制一个应用程序执行的主进程

资源管理器（ResourceManager）: 主要负责管理任务管理器（TaskManager）的插槽（slot），TaskManger插槽是Flink中定义的处理资源单元。

任务管理器（TaskManager）: Flink中的工作进程

分发器（Dispatcher）: 可以跨作业运行，它为应用提交提供了REST接口

![1606393109959](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606393109959.png)

如果部署的集群环境不同（例如YARN，Mesos，Kubernetes，standalone等），其中一些步骤可以被省略，或是有些组件会运行在同一个JVM进程中。



### (0) 提交流程

![1606393159426](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606393159426.png)

Flink任务提交后，Client向HDFS上传Flink的Jar包和配置，之后向Yarn ResourceManager提交任务.

ResourceManager分配Container资源并通知对应的NodeManager启动ApplicationMaster，ApplicationMaster启动后加载Flink的Jar包和配置构建环境，然后启动JobManager.

之后ApplicationMaster向ResourceManager申请资源启动TaskManager，ResourceManager分配Container资源后，由ApplicationMaster通知资源所在节点的NodeManager启动TaskManager，NodeManager加载Flink的Jar包和配置构建环境并启动TaskManager.

TaskManager启动后向JobManager发送心跳包，并等待JobManager向其分配任务。

![1606393340958](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606393340958.png)



当 Flink 集群启动后，首先会启动一个 JobManger 和一个或多个的 TaskManager。由 Client 提交任务给 JobManager，JobManager 再调度任务到各个 TaskManager 去执行，然后 TaskManager 将心跳和统计信息汇报给 JobManager。TaskManager 之间以流的形式进行数据的传输。上述三者均为独立的 JVM 进程。



### (1) TaskManger与Slots

**Task Slot** **是静态的概念，是指TaskManager** **具有的并发执行能力**，可以通过参数taskmanager.numberOfTaskSlots进行配置；而**并行度** **parallelism** **是动态概念，即TaskManager** **运行程序时实际使用的并发能力**，可以通过参数parallelism.default进行配置。



![1606438089478](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606438089478.png)

![1606438106037](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606438106037.png)

![1606438127489](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606438127489.png)

### (2) 程序与数据流（DataFlow）

![1606438157938](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606438157938.png)

所有的Flink程序都是由三部分组成的：  **Source** 、**Transformation**和**Sink**。

Source负责读取数据源，Transformation利用各种算子进行处理加工，Sink负责输出。

在运行时，Flink上运行的程序会被映射成“逻辑数据流”（dataflows），它包含了这三部分。**每一个** **dataflow** **以一个或多个sources** **开始以一个或多个sinks** **结束**。dataflow类似于任意的有向无环图（DAG）。在大部分情况下，程序中的转换运算（transformations）跟dataflow中的算子（operator）是一一对应的关系，但有时候，一个transformation可能对应多个operator。

### (3) 执行图（ExecutionGraph）

Flink 中的执行图可以分成四层：StreamGraph -> JobGraph -> ExecutionGraph -> 物理执行图。

![img](D:\大数据查询资料\flink\photo\clip_image003.jpg)

**StreamGraph**：是根据用户通过 Stream API 编写的代码生成的最初的图。用来表示程序的拓扑结构。

**JobGraph**：StreamGraph经过优化后生成了 JobGraph，提交给 JobManager 的数据结构。主要的优化为，将多个符合条件的节点 chain 在一起作为一个节点，这样可以减少数据在节点之间流动所需要的序列化/反序列化/传输消耗。

**ExecutionGraph**：JobManager 根据 JobGraph 生成ExecutionGraph。ExecutionGraph是JobGraph的并行化版本，是调度层最核心的数据结构。

**物理执行图**：JobManager 根据 ExecutionGraph 对 Job 进行调度后，在各个TaskManager 上部署Task 后形成的“图”，并不是一个具体的数据结构。

### (4) 并行度（Parallelism）

Flink程序的执行具有**并行、分布式**的特性。 **一个特定算子的子任务（subtask）的个数被称之为其并行度（parallelism）**。

![img](D:\大数据查询资料\flink\photo\clip_image004.png)

Stream在算子之间传输数据的形式可以是one-to-one(forwarding)的模式也可以是redistributing的模式，具体是哪一种形式，取决于算子的种类。

**One-to-one**：stream(比如在source和map operator之间)维护着分区以及元素的顺序。那意味着map 算子的子任务看到的元素的个数以及顺序跟source 算子的子任务生产的元素的个数、顺序相同，map、fliter、flatMap等算子都是one-to-one的对应关系。

类似于spark中的**窄依赖**

**Redistributing**：stream(map()跟keyBy/window之间或者keyBy/window跟sink之间)的分区会发生改变。每一个算子的子任务依据所选择的transformation发送数据到不同的目标任务。例如，keyBy() 基于hashCode重分区、broadcast和rebalance会随机重新分区，这些算子都会引起redistribute过程，而redistribute过程就类似于Spark中的shuffle过程。

类似于spark中的**宽依赖**

### (5) 任务链（Operator Chains）

**相同并行度的** **one to one** **操作**，Flink这样相连的算子链接在一起形成一个task，原来的算子成为里面的一部分。将算子链接成task是非常有效的优化：它能减少线程之间的切换和基于缓存区的数据交换，在减少时延的同时提升吞吐量。链接的行为可以在编程API中进行指定。

四个条件:

同一个共享组

one to one 窄依赖

并行度相同

没有被disable切开

![img](D:\大数据查询资料\flink\photo\clip_image006.jpg)

### (6) 共享组

- Flink在调度任务分配Slot的时候遵循两个重要原则：

1. 同一个Job中的同一分组中的不同Task可以共享同一个Slot；

2. Flink是按照拓扑顺序依次从Source调度到sink。

   

   ![1606633979680](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606633979680.png)

   默认情况下，Flink 允许subtasks共享slot，条件是它们都来自同一个Job的不同task的subtask。结果可能一个slot持有该job的整个pipeline。允许槽共享，会有以下两个方面的好处：

   - 对于slot有限的场景，我们可以增大每个task的并行度。比如如果不设置SlotSharingGroup，默认所有task在同一个共享组（可以共享所有slot），那么Flink集群需要的任务槽与作业中使用的最高并行度正好相同。但是如上图所示，如果我们强制指定了map的slot共享组为test，那么map和map下游的组为test，map的上游source的共享组为默认的default，此时default组中最大并行度为10，test组中最大并行度为20，那么需要的Slot=10+20=30；
   - 能更好的利用资源：如果没有slot共享，那些资源需求不大的map/source/flatmap子任务将和资源需求更大的window/sink占用相同的资源，槽资源没有充分利用（内存没有充分利用）。

## 时间语义与Wartermark

### (1) 三种时间语义

![1606439030499](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606439030499.png)

**Event Time**：是事件创建的时间。它通常由事件中的时间戳描述，例如采集的日志数据中，每一条日志都会记录自己的生成时间，Flink通过时间戳分配器访问事件时间戳。

**Ingestion Time**：是数据进入Flink的时间。

**Processing Time**：是每一个执行基于时间操作的算子的本地系统时间，与机器相关，默认的时间属性就是Processing Time。

### (2) Watermark

我们知道，流处理从事件产生，到流经source，再到operator，中间是有一个过程和时间的，虽然大部分情况下，流到operator的数据都是按照事件产生的时间顺序来的，但是也不排除由于网络、分布式等原因，导致乱序的产生，所谓乱序，就是指Flink接收到的事件的先后顺序不是严格按照事件的Event Time顺序排列的。

![1606439138226](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606439138226.png)

那么此时出现一个问题，一旦出现乱序，如果只根据eventTime决定window的运行，我们不能明确数据是否全部到位，但又不能无限期的等下去，此时必须要有个机制来保证一个特定的时间后，必须触发window去进行计算了，这个特别的机制，就是Watermark。

l  Watermark是一种衡量Event Time进展的机制。

l  **Watermark****是用于处理乱序事件的**，而正确的处理乱序事件，通常用Watermark机制结合window来实现。

l  数据流中的Watermark用于表示timestamp小于Watermark的数据，都已经到达了，因此，window的执行也是由Watermark触发的。

l  Watermark可以理解成一个延迟触发机制，我们可以设置Watermark的延时时长t，每次系统会校验已经到达的数据中最大的maxEventTime，然后认定eventTime小于maxEventTime - t的所有数据都已经到达，如果有窗口的停止时间等于maxEventTime – t，那么这个窗口被触发执行。

有序流的Watermarker如下图所示：（Watermark设置为0）

![1606439305967](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606439305967.png)

乱序流的Watermarker如下图所示：（Watermark设置为2）

![1606439328542](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606439328542.png)

当Flink接收到数据时，会按照一定的规则去生成Watermark，这条Watermark就等于当前所有到达数据中的maxEventTime - 延迟时长，也就是说，Watermark是基于数据携带的时间戳生成的，一旦Watermark比当前未触发的窗口的停止时间要晚，那么就会触发相应窗口的执行。由于event time是由数据携带的，因此，如果运行过程中无法获取新的数据，那么没有被触发的窗口将永远都不被触发。

上图中，我们设置的允许最大延迟到达时间为2s，所以时间戳为7s的事件对应的Watermark是5s，时间戳为12s的事件的Watermark是10s，如果我们的窗口1是1s~5s，窗口2是6s~10s，那么时间戳为7s的事件到达时的Watermarker恰好触发窗口1，时间戳为12s的事件到达时的Watermark恰好触发窗口2。

Watermark 就是触发前一窗口的“关窗时间”，一旦触发关门那么以当前时刻为准在窗口范围内的所有所有数据都会收入窗中。

只要没有达到水位那么不管现实中的时间推进了多久都不会触发关窗。

**总结: 1 真实数据,需要传递,决定了算子fire and purge; 2 下游高并发则传递全部并发, 上游高并发则全部接受并按照最小值向下游传递**

## API区分

## 状态类型

### (1) manager状态

包含两种 算子状态和键控状态

#### 算子状态（operator state）(很少使用)

算子状态的作用范围限定为算子任务。这意味着由同一并行任务所处理的所有数据都可以访问到相同的状态，状态对于同一任务而言是共享的。算子状态不能由相同或不同算子的另一个任务访问。

![1606635107379](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606635107379.png)

Flink为算子状态提供三种基本数据结构：

l  列表状态（List state）

将状态表示为一组数据的列表。

l  联合列表状态（Union list state）

也将状态表示为数据的列表。它与常规列表状态的区别在于，在发生故障时，或者从保存点（savepoint）启动应用程序时如何恢复。

l  广播状态（Broadcast state）

如果一个算子有多项任务，而它的每项任务状态又都相同，那么这种特殊情况最适合应用广播状态。

#### 键控状态（keyed state）

键控状态是根据输入数据流中定义的键（key）来维护和访问的。Flink为每个键值维护一个状态实例，并将具有相同键的所有数据，都分区到同一个算子任务中，这个任务会维护和处理这个key对应的状态。当任务处理一条数据时，它会自动将状态的访问范围限定为当前数据的key。因此，具有相同key的所有数据都会访问相同的状态。Keyed State很类似于一个分布式的key-value map数据结构，只能用于KeyedStream（keyBy算子处理之后）。

![1606635311644](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606635311644.png)

Flink的Keyed State支持以下数据类型：

1. ValueState<T>保存单个的值，值的类型为T。

o   get操作: ValueState.value()

o   set操作: ValueState.update(T value)

2. ListState<T>保存一个列表，列表里的元素的数据类型为T。基本操作如下：

o   ListState.add(T value)

o   ListState.addAll(List<T> values)

o   ListState.get()返回Iterable<T>

o   ListState.update(List<T> values)

3. MapState<K, V>保存Key-Value对。

o   MapState.get(UK key)

o   MapState.put(UK key, UV value)

o   MapState.contains(UK key)

o   MapState.remove(UK key)

4. ReducingState<T>

5. AggregatingState<I, O>

State.clear() 是清空操作。

### (2) raw状态

原始状态,需要自己管理 存储和重启之后的加载

## 状态后端（State Backends）

•状态的存储、访问以及维护，由一个可插入的组件决定，这个组件就叫做**状态后端**（state backend）

•状态后端主要负责两件事：本地的状态管理，以及将检查点（checkpoint）状态写入远程存储

1. MemoryStateBackend

•内存级的状态后端，会将键控状态作为内存中的对象进行管理，将它们存储在 TaskManager 的 JVM 堆上，而将 checkpoint 存储在 JobManager 的内存中

•特点：快速、低延迟，但不稳定

2. FsStateBackend

•将 checkpoint 存到远程的持久化文件系统（FileSystem）上，而对于本地状态，跟 MemoryStateBackend 一样，也会存在 TaskManager 的 JVM 堆上

•同时拥有内存级的本地访问速度，和更好的容错保证

3. RocksDBStateBackend

•将所有状态序列化后，存入本地的 RocksDB 中存储。

由于RocksDBStateBackend将工作状态存储在taskManger的本地文件系统，状态数量仅仅受限于本地磁盘容量限制，对比于FsStateBackend保存工作状态在内存中，RocksDBStateBackend能避免flink任务持续运行可能导致的状态数量暴增而内存不足的情况，**因此适合在生产环境使用。**



## 状态一致性(Checkpoints)

![1606636445240](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606636445240.png)

Flink 故障恢复机制的核心，就是应用状态的一致性检查点

有状态流应用的一致检查点，其实就是所有任务的状态，在某个时间点的一份拷贝（一份快照）；这个时间点，应该是所有任务都恰好处理完一个相同的输入数据的时候

状态恢复:

•在执行流应用程序期间，Flink 会定期保存状态的一致检查点

•如果发生故障， Flink 将会使用最近的检查点来一致恢复应用程序的状态，并重新启动处理流程

### 检查点的实现算法

•Flink 的改进实现

​        —— 基于 Chandy-Lamport 算法的分布式快照

•Flink 的检查点算法用到了一种称为分界线（barrier）的特殊数据形式，用来把一条流上数据按照不同的检查点分开

•分界线之前到来的数据导致的状态更改，都会被包含在当前分界线所属的检查点中；而基于分界线之后的数据导致的所有更改，就会被包含在之后的检查点中

​        —— 将检查点的保存和数据处理分离开，不暂停整个应用

### 保存点机制（Savepoints）

•Flink 还提供了可以自定义的镜像保存功能，就是保存点（savepoints）

•原则上，创建保存点使用的算法与检查点完全相同，因此保存点可以认为就是具有一些额外元数据的检查点

•Flink不会自动创建保存点，因此用户（或者外部调度程序）必须明确地触发创建操作 

•保存点是一个强大的功能。除了故障恢复外，保存点可以用于：有计划的手动备份，更新应用程序，版本迁移，暂停和重启应用，等等

### 端到端的状态一致性保证

端到端的一致性保证，意味着结果的正确性贯穿了整个流处理应用的始终；每一个组件都保证了它自己的一致性，整个端到端的一致性级别取决于所有组件中**一致性最弱的组件**。

1. 内部保证 —— 依赖checkpoint

2. source 端 —— 需要外部源可重设数据的读取位置

3. sink 端 —— 需要保证从故障恢复时，数据不会重复写入外部系统

而对于sink端，又有两种具体的实现方式：幂等（Idempotent）写入和事务性（Transactional）写入。

l  sink幂等写入

所谓幂等操作，是说一个操作，可以重复执行很多次，但只导致一次结果更改，也就是说，后面再重复执行就不起作用了。

l  sink事务写入

需要构建事务来写入外部系统，构建的事务对应着 checkpoint，等到 checkpoint 真正完成的时候，才把所有对应的结果写入 sink 系统中。

对于事务性写入，具体又有两种实现方式：预写日志（WAL）和两阶段提交（2PC）。DataStream API 提供了GenericWriteAheadSink模板类和TwoPhaseCommitSinkFunction
接口，可以方便地实现这两种方式的事务性写入。

![1606637161036](D:\大数据查询资料\flink\photo\%5CUsers%5Cyhm%5CAppData%5CRoaming%5CTypora%5Ctypora-user-images%5C1606637161036.png)

## 背压机制(back pressure)

flink能够自己解决背压机制,官方给出了监控方法 100个样本的堆栈跟踪,看source有多少比例被阻塞,通过缓存区的共用,如果下游处理占用了缓存区,source就会被相应的阻塞
	OK：0 <= Ratio <= 0.10
	LOW：0.10 <Ratio <= 0.5
	HIGH：0.5 <Ratio <= 1

Streaming 的背压主要是根据下游任务的执行情况等，来控制上游的速率。Flink 的背压是通过一定时间内堆栈跟踪，监控阻塞的比率来确定背压的。

