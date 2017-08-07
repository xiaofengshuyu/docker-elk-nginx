#!/bin/bash

# build nginx logstash config file

mkdir /config-dir/

cat << EOF > /config-dir/nginx-access.conf
input {
    file {
        type => "nginx-access"
        path => [ "/var/log/nginx/$ACCESS_LOG_FILE_NAME" ]
        tags => [ "nginx","access"]
        start_position => beginning
    }
}

filter {
    if [type] == "nginx-access" {
        grok {
            match => { "message" => "%{COMBINEDAPACHELOG} %{QS:x_forwarded_for}"}
        }
        date {
            match => [ "timestamp" , "dd/MMM/YYYY:HH:mm:ss Z" ]
        }
        geoip {
            source => "clientip"
        }
    }
}

output {
    elasticsearch {
        hosts => "$ELASTICSEARCH_HOST:9200"
        index => "logstash-%{type}-%{+YYYY.MM.dd}"
    }
    stdout { codec => rubydebug }
}
EOF
#        match => { "request" => '"%{WORD:verb} %{URIPATH:urlpath}(?:\?%{NGX_URIPARAM:urlparam})?(?: HTTP/%{NUMBER:httpversion})"' }

cat << EOF > /config-dir/nginx-error.conf
input {
    file {
        type => "nginx-error"
        path => [ "/var/log/nginx/$ERROR_LOG_FILE_NAME" ]
        tags => [ "nginx","error"]
        start_position => beginning
    }
}
filter {
    if [type] == "nginx-error" {
        grok {
            match => { "message" => "(?<datetime>\d\d\d\d/\d\d/\d\d \d\d:\d\d:\d\d) \[(?<errtype>\w+)\] \S+: \*\d+ (?<errmsg>[^,]+), (?<errinfo>.*)$" }
        }
        mutate {
            rename => [ "host", "fromhost" ]
            gsub => [ "errmsg", "too large body: \d+ bytes", "too large body" ]
        }
        if [errinfo]
        {
            ruby {
                code => "
                    new_event = LogStash::Event.new(Hash[event.get('errinfo').split(', ').map{|l| l.split(': ')}])
                    new_event.remove('@timestamp')
                    event.append(new_event)
                "
            }
        }
        grok {
            match => { "request" => '"%{WORD:verb} %{URIPATH:urlpath}(?: HTTP/%{NUMBER:httpversion})"' }
            patterns_dir => ["/etc/logstash/patterns"]
            remove_field => [ "message", "errinfo", "request" ]
        }
    }
}

output {
    elasticsearch {
        hosts => "$ELASTICSEARCH_HOST:9200"
        index => "logstash-%{type}-%{+YYYY.MM.dd}"
    }
    stdout { codec => rubydebug }
}
EOF

logstash -f /config-dir/
