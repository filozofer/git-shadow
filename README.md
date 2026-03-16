# Git Shadow Branch Workflow

A lightweight Git workflow that allows developers to keep **local design comments** and **possibly others things** in their code without pushing them to the shared repository.

![MIT License](https://img.shields.io/badge/license-MIT-green)
![Experimental](https://img.shields.io/badge/status-experimental-blue)
![Git Tooling](https://img.shields.io/badge/tooling-git-orange)
![Shell Scripts](https://img.shields.io/badge/scripts-bash-lightgrey)
![Workflow](https://img.shields.io/badge/workflow-shadow--branch-purple)

This toolkit provides a small set of commands and hooks that create a **shadow branch workflow**:

* **Public branches** → clean code shared with the team
* **Local shadow branches (`@local`)** → personal design comments, navigation markers, local dev env improvements...

The result: you can keep your code comments and local features when your team does not want them !

---

# Why this exists

In mature engineering teams, it is useful to distinguish two things:

* **Final code conventions** (spacing, identation, naming, structure, architecture)
* **Author thinking style** (how developers structure their reasoning)

The first should be consistent across the team.
**The second can legitimately vary.**

Some developers reason mainly through abstraction and refactoring.
Others prefer a more narrative approach, outlining the steps of an algorithm with comments before implementing them (it's called comment driven development). 
These comments are usefull during the implementing phase and during the future reading / improvement phases for these kind of people.
There are not just "noise" but usefull working memory which improve by far their capacities and the team capacities. 

Sometimes, however, teams can decide that your comments should not be present in the shared codebase because there are consider as "not usefull" and "will not be read by team members" and "will not be maintain while the code evolve".
If for whatever reason, your are in a team which refuses to understand your way of thinking (yours needs) or prefer you to leave the company rather than tolerate your coding method, this project exists so you can **still keep your comments locally**.

As a co-benefit usage, if you have commits which you only want to keep in your @local branch it's also possible using this shadow branch workflow.
Example of usages : 
- Remove some form validations rules inside your dev env only
- Local env improvements which your team does not want to use
- Scripts for your usage only

---

# Concept

Each feature exists in **two branches**.

```
feature/login@local   ← contains local comments
feature/login         ← clean branch pushed to your remote git repository
```

Your development happens in the `@local` branch.

When you finish working and want to commit your work you can call the git publish command :

```
git shadow publish my-project
```

The toolkit:

1. strips `/// ` comments (or other pattern you configure)
2. creates two commits : one with your changes and one with your local comments
3. then cherry-picks it to the public branch

---

# Installation

## 1 Clone the toolkit

Place it inside your workspace directory (next to your projects).

Example structure:

```
workspace/
├─ git-local-comments-workflow
├─ project-a
├─ project-b
```

Clone:

```bash
git clone https://github.com/filozofer/git-local-comments-workflow.git
```

---

## 2 Configure environment

Copy the configuration file:

```bash
cp .env.example .env
```

You can leave all the default values or rather adapt to your needs.
Example configuration:

```
WORKSPACE_DIR="../"
PUBLIC_BASE_BRANCH="develop"
LOCAL_SUFFIX="@local"
LOCAL_COMMENT_PATTERN='^[[:space:]]*(///|##|---|;;|%%|<!---|/\*\*|\*)'

```

---

## 3 Make `git-shadow` available

Option 1 (recommended): add the toolkit `bin` folder to your PATH, then use the wrapper directly:

```bash
export PATH="$PWD/bin:$PATH"
# now you can run:
# git-shadow commit my-project -m "message"
# git-shadow publish my-project
```

Option 2: create a Git alias to run the wrapper as `git shadow`:

```bash
git config --global alias.shadow "!sh /chemin/vers/git-shadow/bin/git-shadow"
```

---

## 4 Install the pre-commit hook

For each project:

```bash
git shadow install-hook my-project
```

The hook prevents accidental commits containing your local comment pattern (by default one extra comment marker, see LOCAL_COMMENT_PATTERN env var).
The hook will not provoke error on other team members environments if they haven't install git shadow.

---

# Commands

All commands receive the **project directory** as their first argument.

Example : 

```bash
git shadow publish my-project
```

---

# Create a feature

```bash
git shadow new-feature my-project feature/login
```

Creates:

```
feature/login
feature/login@local
```

and switches to:

```
feature/login@local
```

---

# Work locally

Write your code normally on your "@local" branch.

Example (look at the triple "/" used for comments here):

```ts
  /// Get user from database
  const user = await prisma.user.findUnique({
    where: { email },
  })
  if (!user) {
    throw new Error('Invalid credentials')
  }

  /// Verify if user is able to connect
  if (!user.isActive) {
    throw new Error('User account is disabled')
  }

  /// Verify user password
  const isPasswordValid = await bcrypt.compare(password, user.passwordHash)
  if (!isPasswordValid) {
    throw new Error('Invalid credentials')
  }

  /// Build session for user
  const session = await prisma.session.create({
    data: {
      userId: user.id,
      token: crypto.randomUUID(),
      createdAt: new Date(),
    },
  })

```

---

# Publish work

```bash
git add .
git shadow commit my-project -m "feat(auth): user login function"
git shadow publish my-project

# OR 
git add .
git shadow publish my-project --commit -m "feat(auth): user login function"
```

This:

1. removes local comments from staged code
2. commits your changes in two commits : one with your changes and one with your local comments
3. cherry-picks the commits without comments from your @local branch to the public branch (every commit with a title which begin by [COMMENTS], [COMMENT] or [LOCAL])

Push normally:

```bash
git push origin feature/login
```

If you have commits which you only want to keep in your @local branch your can prefix them with "[LOCAL]" inside theirs titles.
Example of usages : 
- Remove some form validations rules inside your dev env only
- Local env improvements which your team does not want to use
- Scripts for your usage only

---

# Finish a feature

After the MR is merged :

```bash
git shadow finish-feature my-project
```

This command:

* updates your main branch (default : `develop`)
* merges your main branch into his "@local" shadow branch (default: `develop@local`)
* merges `feature@local` into `develop@local`
* optionally deletes feature branches

(every branch naming is configurable inside your own .env file)

---

# Workflow overview

```
develop
   │
   ├── feature/login
   │
develop@local
   │
   └── feature/login@local
```

Your develop@local branches keep design comments and local features permanently.

---

# Example daily workflow

Create feature:

```bash
git shadow new-feature my-project feature/user-login
```

Work normally on your @local branch

Publish:

```bash
git shadow publish my-project --commit -m "feat(auth): user login function"
git push
```

Finish after your branch has been merge on the main branch :

```bash
git shadow finish-feature my-project
```

---

# Configuration

The toolkit uses environment variables.

See `.env.example`.

Main options:

```
WORKSPACE_DIR="../"
PUBLIC_BASE_BRANCH="develop"
LOCAL_SUFFIX="@local"
LOCAL_COMMENT_PATTERN='^[[:space:]]*(///|##|---|;;|%%|<!---|/\*\*|\*)'
```

---

# Drawbacks

Everything you can do with this toolkit can also be done manually. This toolkit therefore provides a set of new commands simply to save you time when setting up a shadow local branch pattern. 

Although these commands allow you to use this pattern without any immediate loss of productivity, two major drawbacks should still be noted:

- Your team members won’t benefit from your local commits, since that’s the whole point of this pattern. I would recommend using it only if your team refuses to tolerate your commits (with your comments for example) on the shared repository

-  To maintain your main shadow branch (example: `develop@local`), you’ll have to manage Git conflicts whenever other team members update code segments on which you have local comments. Although these conflicts are generally easy and quick to resolve, they represent a definite drawback compared to simply being able to share all comments with your team

---

# Status

Experimental but stable enough for daily use.

Expect small improvements as the workflow evolves.

---

# Related tools

- Graphite
- ghstack
- StGit

These tools manage stacked changes.
This project manages local shadow branches.

---

# License

MIT
