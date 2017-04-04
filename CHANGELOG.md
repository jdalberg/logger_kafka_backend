2017-4-4 - 0.1.12
        :brod needs to be started in init explicitly in case someone forgot
        to get it running before logger starts its Watcher

0.1.9   More modern brod, and testcase minor updates.

0.1.8   The Kafka key needed to be a configurable part of the metadata. Now configurable
        by setting meta_key in the options. Default is :kafka_key.

0.1.7   kafka_key introduced. The key used when producing to kafka can now be set
        using the metadata by use if :kafka_key

