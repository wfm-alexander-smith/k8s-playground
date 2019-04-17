terragrunt = {
  terraform {
    source = "${find_in_parent_folders("modules")}//mgmt-vpc"
  }

  include = {
    path = "${find_in_parent_folders()}"
  }
}

ssh_authorized_keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA5bxCK62mdxBVGULYNnidGrZwts4dKgmd9DwvB9p/+HkfbwPUPy+R+BIyIbZ4u1uB26eW+Jy8OKd+OhYvXzZyIQJq2s0emoaoM9RNjmCA4/bd8gx50tarlj8e8WtQhfgZax9uRpPuCl0+HBe/1HNmu0izAWRvw+g0zkrtbgxj1+I6RXhyoO0hkwDmnZ5QoHStDwOffBLBflI3rkMqlxC8S0xgtWxOqESLDxDnEhfULs+ShdVDjU+7AKspHCTJTPMqcywv/6wcnR5MyHBGiQVxNQidJW2nEIJ9dQR8D4kCgXq2jjE3AxkQlL5xYcAOTnGUaL/x3mESeTtshRYyTds9Ww== pib@Quari",
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDtHrL+5NGhSFwfuJuY5u7C6n2kHV9fi2QVm7oh4zc9hXtEa/IBetlgLG0o5AhjtOeVlNlrxAE/Mizeoi26l+K36CsNkGTOMZdlcCL3jw6BhAh+b/2DQxkhAhSsfbt1xMXtZyKVEPDgR9jFcJQkpO7uFX4KOx9t7dMSoQE0S0ctGM3ZzElkVgCcvDNKGHMNVkOjSLj2aHzJBEsdQRljHVhw1pwQ3AdLzzRurD7ijHiMET0sxP+TGhA4SV0wJrL2CyNnrCyhr9Or+SAxt5C1QOnDBi9Ox31ngJmxakQgSazfZaZgKzMFK6ZCvUq1BcSCMYCd/FEu9Za42aQD/VqdmfEp brian@brian-P65-P67RGRERA",
]

bastion_instance_type = "t3.large"
