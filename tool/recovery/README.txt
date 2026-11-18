本地低负载地址恢复搜索

启动
1. 在完整工具文件夹内双击“启动恢复.command”。
2. 默认从 input.path 读取本地配置的路径。这个文件只存路径，不存助记词。
3. 也可以把自己的配置命名为 config.env 放在工具旁边；它会优先使用。
4. 按 Ctrl+C 保存退出，重新双击同一个文件夹的启动器会自动续跑。

默认资源控制
- 单计算线程，每计算约 40 毫秒后休息约 120 毫秒，约四分之一单核负载。
- 启动器以 nice 10 降低进程优先级。
- RSS 内存上限 256 MiB。超过时退出，已有进度保留；运行中触发则保存后暂停。
- 每 5 秒原子保存一次进度。突然断电后最多重算最近一小段，不跳过候选。
- 每 30 秒显示进度。日志最多两个约 512 KiB 文件，不会无限增长。
- 同一个 state 目录只允许一个进程运行。
- 不会为每个候选保留对象或结果列表，内存不随搜索次数增长。

本次默认搜索
目标 TRON：TWkvByXfB9QzaLHtMSi83GGaoBLBgE5KE7
目标 EVM：0xe4079dbbc13d661736562ad156c90dce0fa4f705
固定末级索引：925183485
路径：m / purpose' / coin' / account[可硬化或非硬化] / 0 / 925183485
purpose：44、49、84；coin：0、60、195
账户序号从 0 搜索到 2147483647，使用配置文件中的助记词。
这次运行会逐条核对实际地址，先前的 xPub 指纹筛选结果不冒充这里的完成进度。

停止条件
默认 --stop-on either：必须存在助记词派生的私钥，并且它生成的标准地址或旧版错误哈希地址与目标完全一致，才停止。
只有 xPub 能复现地址不会触发找到私钥。

结果明确区分：
- standard_address_match：私钥的标准地址与目标相同。是否能转账仍需核对链上权限。
- legacy_hash_match_only：仅旧版错误哈希匹配。保存的是原派生密钥，它控制的是报告中的标准地址，不代表找回错误地址中的资金。

只接受标准地址匹配时，可在终端运行：
./recover-address --config "/本地/配置文件.env" --state-dir "./state" --stop-on standard
这会保存旧版匹配线索，然后继续搜索标准地址。

进一步降低负载
RECOVERY_CPU_PERCENT=10 ./启动恢复.command
或者直接运行：
./recover-address --config "/本地/配置文件.env" --state-dir "./state" --cpu-percent 10
--cpu-percent 允许 5–75，表示单个核心的占用比例，不是整台电脑。

文件与续跑
state/checkpoint.json：进度和公开结果，不包含助记词或私钥。
state/progress.log：受限大小的日志，不包含助记词或私钥。
state/match-*.private.json：匹配到的派生私钥，只供本机当前用户读取，终端不显示密钥。
默认续跑目录由 state.path 指定。本机发行包指向独立的 .recovery-local/state 私有目录，清理 build 不会删除它。
不要删除这个目录，否则会失去这份续跑进度。移到其他电脑时请修改 input.path 和 state.path 的路径。
不同助记词、目标或搜索路径请使用不同 --state-dir；脚本会拒绝混用进度。
可提高 --account-max 扩展未完成的上限，或改变 CPU、内存限制后续跑。
--account-start 只用于新进度目录；已有目录始终以已保存的游标为准。

输入
支持 .env、JSON 和普通 YAML 标量。读取 COLLECT_MNEMONIC/MNEMONIC/MNEMONICS；JSON 中 MNEMONICS 可以是历史助记词数组。
支持可选 BIP39_PASSPHRASE，它不是钱包解锁密码。脚本不会猜测未知的附加口令。
可以重复指定 --config 读取多份历史配置；最多 32 份不同根密钥。
配置只按数据读取，不会执行 shell 变量、命令或 source 文件。
本工具完全离线，不联网，不发送交易，不把真实配置复制进安装包。

范围限制
脚本持续搜索上述设定的助记词派生路径，直到匹配、用户暂停、触发资源上限，或设定范围遍历完成。
它不保证一定找到，也不是对整个私钥空间的暴力破解。等待更久不能让旧版错误哈希匹配自动变成资金控制权。

自检
./recover-address --self-test
./recover-address --help

源代码：recover_address.dart
该可执行版本适用于 Apple Silicon Mac，不需要安装 Dart 或 Flutter。
