@echo off
echo Starting SampleBank...
for %%f in (target\samplebank-*.jar) do (
    java -jar %%f
)
