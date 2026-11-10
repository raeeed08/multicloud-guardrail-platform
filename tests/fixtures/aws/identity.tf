# rules: IAM-001, IAM-002
# expect: IAM-001
resource "aws_iam_role_policy_attachment" "ci_admin" {
  role       = "ci"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# expect: IAM-001
resource "aws_iam_user_policy_attachment" "bob_admin" {
  user       = "bob"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# safe
resource "aws_iam_role_policy_attachment" "auditor" {
  role       = "auditor"
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

# expect: IAM-002
resource "aws_iam_access_key" "deployer" {
  user = "deployer"
}
