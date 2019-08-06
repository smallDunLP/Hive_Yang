hive小文件测试：
https://blog.csdn.net/i000zheng/article/details/81118753	根据这个
	西安生产集群相关配置：
	hive.exec.compress.output=false		不启动压缩
	mapreduce.output.fileoutputformat.compress=false	和压缩相关吧，也没启用
	
	hive.input.format=org.apache.hadoop.hive.ql.io.CombineHiveInputFormat	默认开启
	
	mapred.max.split.size=256000000
	mapred.min.split.size.per.node=1
	mapred.min.split.size.per.rack=1
	
	set hive.merge.mapfiles=true
	set hive.merge.mapredfiles=false
	hive.merge.size.per.task=268435456
	hive.merge.smallfiles.avgsize=16777216
	
	hive.exec.reducers.bytes.per.reducer=67108864
	hive.exec.reducers.max=1099
	
	mapred.reduce.tasks=-1
	
------	mf1 ------
mf1:		外部表
	对应 /test/yxtest/pay 目录下 487个文件	3个空 平均10M左右		总共5G
	
	1.select count(1) from mf1;	
	什么参数都不改，是用上面的：
		Launching Job 1 out of 1
		Hadoop job information for Stage-1: number of mappers: 21; number of reducers: 1
	
	设置 mapred.max.split.size=64000000；
		Launching Job 1 out of 1
		Hadoop job information for Stage-1: number of mappers: 78; number of reducers: 1
		大概5G/64000000 ≈ 78
	
mf1_c:	内部表
	对应	/user/hive/warehouse/test.db/mf1_c	目录下	21个文件，244*20 + 198 MB	总共5G
	1.select count(1) from mf1_c;
		mapred.max.split.size=256000000
		Launching Job 1 out of 1
		Hadoop job information for Stage-1: number of mappers: 20; number of reducers: 1
	
	2.
		mapred.max.split.size=64000000
		Launching Job 1 out of 1
		Hadoop job information for Stage-1: number of mappers: 64; number of reducers: 1
		感觉像是按block划分的
	

mf1_y:		内部表	orc存储
	对应 /user/hive/warehouse/test.db/mf1_y	目录录下	21个文件	1个80+MB + 20*100MB 	总共2.1G
	1.select count(1) from mf1_y;
	设置 mapred.max.split.size=64000000； 无效，仍是上面个数


------	mf2 ------
mf2:		外部表
	对应 /test/yxtest/pay2 目录下 965 个文件 几个空不知道 平均10M左右	总共10G



	
		
		
	
	
	

1.select count(1) from mf2;
	Launching Job 1 out of 1
	Hadoop job information for Stage-1: number of mappers: 42; number of reducers: 1


有用的参考：
	从上面代码可以看出，如果为 CombineHiveInputFormat，则以下四个参数起作用：
    mapred.min.split.size 或者 mapreduce.input.fileinputformat.split.minsize。
    mapred.max.split.size 或者 mapreduce.input.fileinputformat.split.maxsize。
    mapred.min.split.size.per.rack 或者 mapreduce.input.fileinputformat.split.minsize.per.rack。
    mapred.min.split.size.per.node 或者 mapreduce.input.fileinputformat.split.minsize.per.node。
	
	
	CombineFileInputFormatShim 的 getSplits 方法最终会调用父类的 getSplits 方法，拆分算法如下：

    long left = locations[i].getLength();
    long myOffset = locations[i].getOffset();
    long myLength = 0;
    do {
        if (maxSize == 0) {
            myLength = left;
        } else {
			if (left > maxSize && left < 2 * maxSize) {
			  myLength = left / 2;
			} else {
			  myLength = Math.min(maxSize, left);
			}
        }
        OneBlockInfo oneblock = new OneBlockInfo(path, myOffset,myLength, locations[i].getHosts(), locations[i].getTopologyPaths());
        left -= myLength;
        myOffset += myLength;
     
        blocksList.add(oneblock);
    } while (left > 0);
	
	
这里主要注意maxSize,个人实验等于 mapred.max.split.size 的值

对于西安生产集群来说：
	目前暂时记住可以通过 set mapred.max.split.size 来控制map数		除了orc存储外
	目前暂时记住 set hive.merge.mapredfiles=false 可以控制最后生成的文件数 

	至今未找到JVM重用	JVM reuse(only possible in MR1)
	
	
对于出现问题最严重的YH表

	set hive.merge.mapredfiles=true;
	set mapreduce.map.memory.mb=4096;
	set mapreduce.reduce.memory.mb=8192;
	set hive.exec.reducers.bytes.per.reducer=512000000;
	set mapred.max.split.size=64000000;

其中中间表优化时间缩短到3分钟  原8分中

	hive.exec.parallel=true
	
	hive.merge.mapredfiles=true
	hive.merge.size.per.task=268435456
	hive.merge.smallfiles.avgsize=16777216
	