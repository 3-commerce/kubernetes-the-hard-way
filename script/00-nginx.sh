stream {
        upstream k8s_api {
                server 10.240.0.2:6443;
                server 10.240.0.3:6443;
                server 10.240.0.4:6443;
        }

        server {
                listen 6443;
                proxy_pass k8s_api;
        }
}