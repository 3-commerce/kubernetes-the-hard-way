#!/usr/bin/env bash

gcloud compute routes create "kubernetes-route-10-200-11-0-24" --destination-range "10.200.11.0/24" --network kubernetes-the-hard-way --next-hop-address "10.240.0.12"

gcloud compute routes create "kubernetes-route-10-200-12-0-24" --destination-range "10.200.12.0/24" --network kubernetes-the-hard-way --next-hop-address "10.240.0.13"